// Android emulator -> 10.0.2.2; iOS simulator -> localhost
const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:3000');
