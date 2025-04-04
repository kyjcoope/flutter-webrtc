const String pythonServerHost = 'localhost';
const int pythonServerPort = 8080;
const bool useSecurePythonConnection = false;
const String dartApiHost = '0.0.0.0';
const int dartApiPort = 8081;

final String pythonHttpBaseUrl =
    '${useSecurePythonConnection ? 'https' : 'http'}://$pythonServerHost:$pythonServerPort';
final String pythonWsBaseUrl =
    '${useSecurePythonConnection ? 'wss' : 'ws'}://$pythonServerHost:$pythonServerPort/ws';
