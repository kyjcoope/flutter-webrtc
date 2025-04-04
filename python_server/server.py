import argparse
import asyncio
import json
import logging
import os
import ssl
import time
from typing import Set, Optional, Dict, Tuple, Any
from aiohttp import web
import aiohttp
from aiortc import (
    MediaStreamTrack,
    RTCPeerConnection,
    RTCSessionDescription,
)
from aiortc.contrib.media import MediaRelay
from aiortc.mediastreams import VIDEO_TIME_BASE, VIDEO_CLOCK_RATE, MediaStreamError

try:
    import av
    av_available = True
except ImportError:
    print("Warning: PyAV library not found. Install with 'pip install av'")
    av_available = False

logger = logging.getLogger(__name__)

pcs: Set[RTCPeerConnection] = set()
frame_queues: Dict[str, asyncio.Queue[Optional[Tuple[int, bytes]]]] = {}
source_tracks: Dict[str, 'H264InputTrack'] = {}
relays: Dict[str, MediaRelay] = {}
stream_management_lock = asyncio.Lock()
pc_to_relayed_track: Dict[RTCPeerConnection, MediaStreamTrack] = {}

class H264InputTrack(MediaStreamTrack):
    kind = "video"
    def __init__(self, queue: asyncio.Queue[Optional[Tuple[int, bytes]]], stream_id: str):
        super().__init__()
        self._queue = queue
        self._stream_id = stream_id
        self._start_time: Optional[float] = None
        logger.info(f"H264InputTrack initialized for stream '{self._stream_id}'")

    async def recv(self) -> av.Packet:
        if not av_available:
            logger.error(f"H264InputTrack '{self._stream_id}': PyAV not available.")
            raise MediaStreamError("PyAV library required")

        if self._start_time is None:
            self._start_time = time.time()
            logger.info(f"H264InputTrack '{self._stream_id}': First frame requested, start time {self._start_time:.3f}.")

        queued_item = await self._queue.get()

        if queued_item is None:
             logger.info(f"H264InputTrack '{self._stream_id}': Received stop sentinel.")
             raise MediaStreamError

        pts_ns, frame_data = queued_item
        time_since_start_sec = (pts_ns / 1e9) - self._start_time

        if time_since_start_sec < -0.5:
            logger.warning(f"H264InputTrack '{self._stream_id}': Frame ts ({pts_ns / 1e9:.3f}) << start time ({self._start_time:.3f}). Resetting.")
            self._start_time = pts_ns / 1e9
            time_since_start_sec = 0.0
        elif time_since_start_sec < 0:
             time_since_start_sec = 0.0

        pts = int(time_since_start_sec * VIDEO_CLOCK_RATE)

        try:
            packet = av.Packet(frame_data)
            packet.pts = pts
            packet.time_base = VIDEO_TIME_BASE
            is_keyframe = False
            if len(frame_data) > 4:
                start_code_offset = -1
                if frame_data.startswith(b'\x00\x00\x00\x01'): start_code_offset = 4
                elif frame_data.startswith(b'\x00\x00\x01'): start_code_offset = 3
                if start_code_offset != -1 and len(frame_data) > start_code_offset:
                    nal_unit_type = frame_data[start_code_offset] & 0x1F
                    if nal_unit_type == 5: is_keyframe = True
            packet.is_keyframe = is_keyframe
        except Exception as e:
             logger.error(f"H264InputTrack '{self._stream_id}': Error creating av.Packet: {e}", exc_info=True)
             self._queue.task_done()
             return await self.recv()
        self._queue.task_done()
        return packet

    def stop(self):
        if not getattr(self, '_MediaStreamTrack__ended', True):
            logger.info(f"H264InputTrack '{self._stream_id}': Explicit stop called.")
            try:
                 self._queue.put_nowait(None)
            except asyncio.QueueFull: logger.warning(f"Queue full, couldn't add sentinel on stop for {self._stream_id}")
            except Exception as e: logger.error(f"Error adding sentinel on stop for {self._stream_id}: {e}")
            super().stop()
        else:
             logger.debug(f"H264InputTrack '{self._stream_id}' already stopped.")

async def websocket_handler(request: web.Request):
    ws = web.WebSocketResponse()
    can_prepare = ws.can_prepare(request)
    if not can_prepare.ok:
        logger.warning(f"WebSocket upgrade failed: {can_prepare.reason}")
        return ws
    await ws.prepare(request)
    peername = request.transport.get_extra_info('peername') if request.transport else None
    host, port = peername if peername else ('unknown_host', 0)
    try:
        stream_id = request.match_info['stream_id']
        if not stream_id: raise ValueError("Stream ID cannot be empty")
        logger.info(f"WS client {host}:{port} attempting connection for stream_id: '{stream_id}'")
    except KeyError:
        logger.error(f"WS connection from {host}:{port} missing stream_id.")
        await ws.close(code=aiohttp.WSCloseCode.POLICY_VIOLATION, message=b"Missing stream_id")
        return ws
    except ValueError as e:
        logger.error(f"WS connection from {host}:{port} invalid stream_id: {e}")
        await ws.close(code=aiohttp.WSCloseCode.POLICY_VIOLATION, message=f"Invalid stream_id: {e}".encode())
        return ws
    logger.info(f"WS client connected for stream '{stream_id}': {host}:{port}")
    input_queue: Optional[asyncio.Queue[Optional[Tuple[int, bytes]]]] = None
    created_resources = False
    async with stream_management_lock:
        if stream_id not in frame_queues:
            logger.info(f"First sender for stream '{stream_id}'. Creating resources.")
            created_resources = True
            input_queue = asyncio.Queue(maxsize=60)
            frame_queues[stream_id] = input_queue
            source_tracks[stream_id] = H264InputTrack(input_queue, stream_id)
            relays[stream_id] = MediaRelay()
            logger.info(f"Resources created for stream '{stream_id}'.")
        else:
            input_queue = frame_queues.get(stream_id)
            if input_queue is None:
                 logger.error(f"Inconsistent state: stream '{stream_id}' exists but queue None!")
                 await ws.close(code=aiohttp.WSCloseCode.INTERNAL_ERROR, message=b"Internal error")
                 return ws
            logger.info(f"Existing stream '{stream_id}'. Client {host}:{port} feeding queue.")
    websocket_closed = False
    try:
        async for msg in ws:
            if websocket_closed: break
            if msg.type == aiohttp.WSMsgType.BINARY:
                if input_queue.full():
                    try:
                        dropped_ts, dropped_data = input_queue.get_nowait()
                        input_queue.task_done()
                        logger.warning(f"Queue '{stream_id}' full! Dropped frame.")
                    except asyncio.QueueEmpty: pass
                await input_queue.put((time.time_ns(), msg.data))
            elif msg.type == aiohttp.WSMsgType.TEXT: logger.info(f"WS '{stream_id}' text from {host}:{port} (ignored): {msg.data}")
            elif msg.type == aiohttp.WSMsgType.ERROR:
                logger.error(f"WS '{stream_id}' ({host}:{port}) error: {ws.exception()}")
                websocket_closed = True; break
            elif msg.type == aiohttp.WSMsgType.CLOSE:
                 logger.info(f"WS '{stream_id}' received close from {host}:{port}, code={ws.close_code}")
                 websocket_closed = True; break
            elif msg.type == aiohttp.WSMsgType.CLOSED:
                 logger.info(f"WS '{stream_id}' detected closed for {host}:{port}")
                 websocket_closed = True; break
    except asyncio.CancelledError:
        logger.info(f"WS handler '{stream_id}' ({host}:{port}) cancelled.")
        websocket_closed = True
    except Exception as e:
        logger.error(f"Error in WS handler '{stream_id}' ({host}:{port}): {e}", exc_info=True)
        websocket_closed = True
    finally:
        logger.info(f"WS client '{stream_id}' ({host}:{port}) disconnecting.")
        if not ws.closed:
            await ws.close(code=aiohttp.WSCloseCode.GOING_AWAY, message=b'Handler ending')
        if created_resources:
            logger.info(f"Original WS connection '{stream_id}' closed. Cleaning up resources.")
            async with stream_management_lock:
                track_to_stop = source_tracks.pop(stream_id, None)
                queue_to_clear = frame_queues.pop(stream_id, None)
                relay_to_remove = relays.pop(stream_id, None)
            if track_to_stop:
                logger.info(f"Stopping source track '{stream_id}'.")
                if queue_to_clear:
                    try: queue_to_clear.put_nowait(None)
                    except Exception as e: logger.error(f"Error adding sentinel to queue '{stream_id}': {e}")
                track_to_stop.stop()
            if relay_to_remove: logger.info(f"Relay '{stream_id}' removed.")
            logger.info(f"Resource cleanup '{stream_id}' completed.")
        else:
            logger.info(f"Secondary WS connection '{stream_id}' closed.")
    return ws

async def offer(request: web.Request):
    try:
        stream_id = request.match_info['stream_id']
        if not stream_id: raise ValueError("Stream ID cannot be empty")
        logger.info(f"Offer request for stream_id: '{stream_id}' from {request.remote}")
    except KeyError:
        logger.error(f"Offer request from {request.remote} missing stream_id.")
        return web.Response(status=400, content_type="application/json", text=json.dumps({"error": "Missing stream_id"}))
    except ValueError as e:
        logger.error(f"Offer request from {request.remote} invalid stream_id: {e}")
        return web.Response(status=400, content_type="application/json", text=json.dumps({"error": f"Invalid stream_id: {e}"}))
    try:
        params = await request.json()
        sdp = params.get("sdp")
        sdp_type = params.get("type")
        if not sdp or not sdp_type or sdp_type != "offer":
            logger.error(f"Invalid offer body for '{stream_id}' from {request.remote}.")
            return web.Response(content_type="application/json", text=json.dumps({"error": "Invalid offer body"}), status=400)
        offer_desc = RTCSessionDescription(sdp=sdp, type=sdp_type)
        logger.info(f"Parsed offer for '{stream_id}' from {request.remote}")
        logger.debug(f"{stream_id} OFFER SDP:\n{sdp}")
    except Exception as e:
        logger.error(f"Error processing offer params '{stream_id}': {e}", exc_info=True)
        return web.Response(content_type="application/json", text=json.dumps({"error": f"Error processing request: {e}"}), status=400)
    pc = RTCPeerConnection()
    pc_id = f"PC-{id(pc)}-{stream_id}"
    pcs.add(pc)
    logger.info(f"Created PeerConnection {pc_id}")
    relayed_track_for_pc: Optional[MediaStreamTrack] = None
    @pc.on("connectionstatechange")
    async def on_connectionstatechange():
        logger.info(f"{pc_id}: Connection state: {pc.connectionState}")
        if pc.connectionState in ["failed", "closed", "disconnected"]:
            logger.warning(f"{pc_id}: Closing PC state: {pc.connectionState}")
            asyncio.ensure_future(cleanup_pc(pc, pc_id))
    @pc.on("iceconnectionstatechange")
    async def on_iceconnectionstatechange():
        logger.info(f"{pc_id}: ICE state: {pc.iceConnectionState}")
        if pc.iceConnectionState in ["failed", "closed", "disconnected"]:
            logger.warning(f"{pc_id}: Closing PC ICE state: {pc.iceConnectionState}")
            asyncio.ensure_future(cleanup_pc(pc, pc_id))
    @pc.on("track")
    def on_track(track: MediaStreamTrack):
        logger.warning(f"{pc_id}: Track {track.kind} ({track.id}) received unexpectedly. Stopping.")
        if hasattr(track, 'stop'): track.stop()
    async with stream_management_lock:
        source_track: Optional[H264InputTrack] = source_tracks.get(stream_id)
        relay: Optional[MediaRelay] = relays.get(stream_id)
    if source_track is None or relay is None:
        logger.error(f"{pc_id}: Stream '{stream_id}' not found or source WS not connected.")
        await cleanup_pc(pc, pc_id)
        return web.Response(content_type="application/json", text=json.dumps({"error": f"Stream '{stream_id}' unavailable"}), status=404)
    try:
        if getattr(source_track, '_MediaStreamTrack__ended', False):
             raise RuntimeError(f"Source track '{stream_id}' stopped.")
        relayed_track_for_pc = relay.subscribe(source_track)
        logger.info(f"{pc_id}: Subscribed to relayed track '{stream_id}'.")
        pc_to_relayed_track[pc] = relayed_track_for_pc
    except Exception as e:
        logger.error(f"{pc_id}: Failed subscribe relay '{stream_id}': {e}", exc_info=True)
        await cleanup_pc(pc, pc_id)
        return web.Response(content_type="application/json", text=json.dumps({"error": f"Subscribe error: {e}"}), status=500)
    try:
        logger.info(f"{pc_id}: Adding video transceiver with relayed track (dir=sendonly)...")
        video_transceiver = pc.addTrack(relayed_track_for_pc)
        video_transceiver.direction = "sendonly"
        logger.info(f"{pc_id}: Adding inactive audio transceiver...")
        pc.addTransceiver("audio", direction="inactive")
        logger.info(f"{pc_id}: Setting remote description (offer)...")
        await pc.setRemoteDescription(offer_desc)
        logger.info(f"{pc_id}: Remote description set.")
        logger.debug(f"{pc_id}: Transceivers after setRemoteDescription:")
        for t in pc.getTransceivers():
             logger.debug(f"  - Kind:{t.kind}, MID:{t.mid}, Dir:{t.direction}, Sender:{t.sender is not None}, Receiver:{t.receiver is not None}")
        logger.info(f"{pc_id}: Creating answer...")
        answer = await pc.createAnswer()
        logger.info(f"{pc_id}: Answer created.")
        logger.debug(f"{pc_id}: ANSWER SDP (before setLocal):\n{answer.sdp}")
        logger.info(f"{pc_id}: Setting local description (answer)...")
        await pc.setLocalDescription(answer)
        logger.info(f"{pc_id}: Local description set.")
        if not (pc.localDescription and pc.localDescription.sdp):
            logger.error(f"{pc_id}: Local SDP missing!")
            raise RuntimeError("Local SDP missing")
        final_sender = next((s for s in pc.getSenders() if s.track == relayed_track_for_pc), None)
        if not final_sender: logger.warning(f"{pc_id}: Sender verification failed.")
        else: logger.info(f"{pc_id}: Verified sender association.")
    except Exception as e:
        logger.error(f"{pc_id}: Error during offer/answer: {e}", exc_info=True)
        await cleanup_pc(pc, pc_id)
        error_message = f"Negotiation error '{stream_id}': {e}"
        return web.Response(content_type="application/json", text=json.dumps({"error": error_message}), status=500)
    logger.info(f"{pc_id}: Negotiation successful. Sending answer to {request.remote}")
    response_data = {"sdp": pc.localDescription.sdp, "type": pc.localDescription.type}
    return web.Response(content_type="application/json", text=json.dumps(response_data), status=200)

async def cleanup_pc(pc: RTCPeerConnection, pc_id: str):
    if pc not in pcs:
        logger.debug(f"Cleanup requested for {pc_id}, but already removed.")
        return
    logger.info(f"Cleaning up {pc_id}...")
    pcs.discard(pc)
    relayed_track = pc_to_relayed_track.pop(pc, None)
    if relayed_track:
        logger.info(f"{pc_id}: Stopping associated relayed track {id(relayed_track)}...")
        if hasattr(relayed_track, 'stop'):
            relayed_track.stop()
        else:
            logger.warning(f"{pc_id}: Relayed track object has no stop() method.")
    else:
        logger.warning(f"{pc_id}: No relayed track found in map during cleanup.")
    try:
        await pc.close()
        logger.info(f"{pc_id} closed successfully.")
    except Exception as e:
        logger.error(f"Error closing {pc_id}: {e}", exc_info=True)

async def on_startup(app: web.Application):
    logger.info("Server starting up...")
    logger.info("Stream management dictionaries initialized.")

async def on_shutdown(app: web.Application):
    logger.info("Shutting down server...")
    active_pcs = list(pcs)
    logger.info(f"Closing {len(active_pcs)} active peer connection(s)...")
    await asyncio.gather(*(cleanup_pc(pc, f"PC-{id(pc)}-shutdown") for pc in active_pcs), return_exceptions=True)
    if pcs: logger.warning(f"{len(pcs)} PCs remained after shutdown cleanup.")
    pcs.clear()
    pc_to_relayed_track.clear()
    logger.info("Peer connections closed and associations cleared.")
    logger.info(f"Stopping {len(source_tracks)} active source track(s)...")
    async with stream_management_lock:
        tracks_to_stop = list(source_tracks.values())
        queues_to_signal = list(frame_queues.values())
        for queue in queues_to_signal:
            try: queue.put_nowait(None)
            except Exception as e: logger.error(f"Error putting None in queue: {e}")
        for track in tracks_to_stop:
            logger.info(f"Stopping source track '{track._stream_id}' during shutdown...")
            track.stop()
        source_tracks.clear()
        frame_queues.clear()
        relays.clear()
    await asyncio.sleep(0.2)
    logger.info("Stream resources cleared.")
    logger.info("Shutdown complete.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="WebRTC Multi-Stream H.264 Input Server")
    parser.add_argument("--host", default="localhost", help="Host (default: localhost)")
    parser.add_argument("--port", type=int, default=8080, help="Port (default: 8080)")
    parser.add_argument("--cert-file", help="SSL certificate file (for HTTPS/WSS)")
    parser.add_argument("--key-file", help="SSL key file (for HTTPS/WSS)")
    parser.add_argument("-v", "--verbose", help="Increase logging verbosity", action="store_true")
    args = parser.parse_args()
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(level=log_level, format='%(asctime)s %(levelname)-8s %(name)s: %(message)s')
    logger.setLevel(log_level)
    logging.getLogger("aiortc").setLevel(logging.INFO if args.verbose else logging.WARN)
    logging.getLogger("aiohttp").setLevel(logging.INFO)
    if args.verbose: logger.info("Verbose logging enabled.")
    ssl_context = None
    protocol, ws_protocol = "http", "ws"
    if args.cert_file and args.key_file:
        if not os.path.exists(args.cert_file): logger.error(f"Cert file not found: {args.cert_file}"); exit(1)
        if not os.path.exists(args.key_file): logger.error(f"Key file not found: {args.key_file}"); exit(1)
        ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        try:
            ssl_context.load_cert_chain(args.cert_file, args.key_file)
            logger.info(f"SSL context loaded from {args.cert_file}, {args.key_file}.")
            protocol, ws_protocol = "https", "wss"
        except Exception as e:
            logger.error(f"Error loading SSL cert/key: {e}. Serving HTTP.", exc_info=True)
            ssl_context = None
    else:
        logger.info("SSL cert/key not provided. Serving HTTP/WS.")
    app = web.Application(logger=logger)
    app["args"] = args
    app.on_startup.append(on_startup)
    app.on_shutdown.append(on_shutdown)
    app.router.add_post("/offer/{stream_id}", offer)
    app.router.add_get("/ws/{stream_id}", websocket_handler)
    server_url = f"{protocol}://{args.host}:{args.port}"
    logger.info(f"Starting server on {server_url}")
    logger.info(f"WebSocket: {ws_protocol}://{args.host}:{args.port}/ws/{{stream_id}}")
    logger.info(f"Signaling: {protocol}://{args.host}:{args.port}/offer/{{stream_id}}")
    try:
        web.run_app(app, host=args.host, port=args.port, ssl_context=ssl_context, access_log=None)
    except OSError as e: logger.error(f"Failed start server {args.host}:{args.port}. Error: {e}")
    except Exception as e: logger.error(f"Unexpected server startup error: {e}", exc_info=True)