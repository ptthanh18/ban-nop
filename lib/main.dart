import 'dart:async';
import 'dart:convert' show utf8;
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestBluetoothPermission();
  runApp(const MyApp());
}

Future<void> _requestBluetoothPermission() async {
  PermissionStatus bluetoothStatus = await Permission.bluetooth.status;
  PermissionStatus locationStatus = await Permission.location.status;

  if (bluetoothStatus != PermissionStatus.granted) {
    bluetoothStatus = await Permission.bluetooth.request();
    if (bluetoothStatus != PermissionStatus.granted) {
      print('Quyền BLUETOOTH không được cấp');
    }
  }

  if (locationStatus != PermissionStatus.granted) {
    locationStatus = await Permission.location.request();
    if (locationStatus != PermissionStatus.granted) {
      print('Quyền VỊ TRÍ không được cấp');
    }
  }
}

class BluetoothConnectionManager {
  static final BluetoothConnectionManager _instance =
  BluetoothConnectionManager._internal();
  factory BluetoothConnectionManager() {
    return _instance;
  }
  BluetoothConnection? _connection;
  BluetoothConnection? get connection => _connection;
  set connection(BluetoothConnection? connection) {
    _connection = connection;
  }
  BluetoothConnectionManager._internal();
}

class ArduinoController {
  void openRelay(int relayNumber) {
    print('Mở rờ le $relayNumber');
  }

  void closeRelay(int relayNumber) {
    print('Đóng rờ le $relayNumber');
  }
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: const BluetoothScanPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BluetoothDeviceList extends StatefulWidget {
  const BluetoothDeviceList({Key? key}) : super(key: key);

  @override
  _BluetoothDeviceListState createState() => _BluetoothDeviceListState();
}

class _BluetoothDeviceListState extends State<BluetoothDeviceList> {
  List<BluetoothDevice> devices = [];
  Set<String> seenDevices = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    Timer(const Duration(seconds: 6), stopScan);

    FlutterBluetoothSerial.instance.startDiscovery().listen(
          (BluetoothDiscoveryResult result) {
        if (!mounted) return;
        if (!seenDevices.contains(result.device.address)) {
          setState(() {
            devices.add(result.device);
            seenDevices.add(result.device.address);
          });
        }
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
      },
      onError: (dynamic error) {
        if (!mounted) return;

        print('Error during Bluetooth scanning: $error');
        setState(() {
          isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bluetooth Scan'),
        ),
        body: isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : ListView.builder(
          itemCount: devices.length,
          itemBuilder: (context, index) {
            BluetoothDevice device = devices[index];
            return BluetoothDeviceListItem(
              device: device,
              onConnect: () => _connectToDevice(device),
            );
          },
        ),
      ),
    );
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      BluetoothConnection connection =
      await BluetoothConnection.toAddress(device.address);
      print('Connected to ${device.name}');
      BluetoothConnectionManager().connection = connection;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const BluetoothControlPage(),
        ),
      );
    } catch (e) {
      print('Error connecting to ${device.name}: $e');
    }
  }

  void stopScan() {
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }
}

class BluetoothDeviceListItem extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback onConnect;

  const BluetoothDeviceListItem({
    Key? key,
    required this.device,
    required this.onConnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(device.name ?? 'Thiết Bị Không Xác Định'),
      subtitle: Text(device.address),
      trailing: ElevatedButton(
        onPressed: onConnect,
        child: const Text('Kết Nối'),
      ),
    );
  }
}

class BluetoothScanPage extends StatelessWidget {
  const BluetoothScanPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: BluetoothDeviceList(),
    );
  }
}

class BluetoothControlPage extends StatelessWidget {
  const BluetoothControlPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: BluetoothControl(),
    );
  }
}

class BluetoothControl extends StatefulWidget {
  const BluetoothControl({Key? key}) : super(key: key);

  @override
  _BluetoothControlState createState() => _BluetoothControlState();
}

class _BluetoothControlState extends State<BluetoothControl> {
  List<String> options = [
    'Pan xi nhan trái',
    'Pan xi nhan phải',
    'Pan đèn pha',
    'Pan đèn cos',
    'Pan công tắc pha cos',
    'Pan đèn phanh',
    'Pan công tắc đèn đầu',
    'Pan còi',
    'Pan dương nguồn',
    'Pan mass nguồn'
  ];
  String selectedOption = 'Pan xi nhan trái';
  ArduinoController arduinoController = ArduinoController();

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext builderContext) {
        return SizedBox(
          height: 320,
          child: ListWheelScrollView(
            itemExtent: 45,
            onSelectedItemChanged: (int index) {
              setState(() {
                selectedOption = options[index];
              });
            },
            children: options.map((option) {
              return Center(
                child: Text(
                  option,
                  style: const TextStyle(fontSize: 25),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text('Điều Khiển Từ Xa'),
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: () => _showBottomSheet(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedOption,
                    style: const TextStyle(fontSize: 25),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        print('Bật');
                        _sendCommandBasedOnOption(selectedOption, 'open');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.cyanAccent,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(30.0),
                        child: Text('Bật', style: TextStyle(fontSize: 50)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        print('Tắt');
                        _sendCommandBasedOnOption(selectedOption, 'close');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.cyanAccent,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(30.0),
                        child: Text('Tắt', style: TextStyle(fontSize: 50)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendCommandBasedOnOption(String selectedOption, String action) {
    List<String> options = [
      'Pan xi nhan trái',
      'Pan xi nhan phải',
      'Pan đèn pha',
      'Pan đèn cos',
      'Pan công tắc pha cos',
      'Pan đèn phanh',
      'Pan công tắc đèn đầu',
      'Pan còi',
      'Pan dương nguồn',
      'Pan mass nguồn'
    ];
    int commandIndex = options.indexOf(selectedOption);
    String command;

    if (commandIndex != -1) {
      switch (action) {
        case 'open':
          switch (commandIndex) {
            case 0:
              command = '0';
              break;
            case 1:
              command = '1';
              break;
            case 2:
              command = '2';
              break;
            case 3:
              command = '3';
              break;
            case 4:
              command = '4';
              break;
            case 5:
              command = '5';
              break;
            case 6:
              command = '6';
              break;
            case 7:
              command = '7';
              break;
            case 8:
              command = '8';
              break;
            case 9:
              command ='9';
              break;
            default:
              print('Không có tín hiệu mở relay tương ứng');
              return;
          }
          break;
        case 'close':
          switch (commandIndex) {
            case 0:
              command = 'a';
              break;
            case 1:
              command = 'b';
              break;
            case 2:
              command = 'c';
              break;
            case 3:
              command = 'd';
              break;
            case 4:
              command = 'e';
              break;
            case 5:
              command = 'f';
              break;
            case 6:
              command = 'g';
              break;
            case 7:
              command = 'h';
              break;
            case 8:
              command = 'i';
              break;
            case 9:
              command = 'k';
              break;
            default:
              print('Không có tín hiệu đóng relay tương ứng');
              return;
          }
          break;
        default:
          print('Hành động không được nhận dạng.');
          return;
      }
    } else {
      print('Không tìm thấy tùy chọn được chọn trong danh sách.');
      return;
    }

    BluetoothConnection? connection = BluetoothConnectionManager().connection;
    if (connection != null && connection.isConnected) {
      _sendControlCommand(connection, command);
      if (action == 'open') {
        ArduinoController().openRelay(commandIndex + 1);
      } else if (action == 'close') {
        ArduinoController().closeRelay(commandIndex + 1);
      }
    } else {
      print('Không có kết nối Bluetooth.');
    }
  }

  void _sendControlCommand(BluetoothConnection connection, String command) {
    print('Sent: $command');
    try {
      connection.output.add(utf8.encode(command));
      connection.output.allSent.then((_) {
        print('Sent: $command');
      });
    } catch (e) {
      print('Error sending command: $e');
    }
  }
}
