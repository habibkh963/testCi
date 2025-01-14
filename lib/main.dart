import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Draw on Image',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DrawOnImage(),
    );
  }
}

class DrawOnImage extends StatefulWidget {
  @override
  _DrawOnImageState createState() => _DrawOnImageState();
}

class _DrawOnImageState extends State<DrawOnImage> {
  List<Offset> points = [];
  ui.Image? image;
  ui.Image? resizedImage;
  File? savedImage;
  Size? imageSize;

  @override
  void initState() {
    super.initState();
    loadImage();
  }

  Future<void> loadImage() async {
    final ByteData data = await rootBundle.load('assets/car2.png');
    final Uint8List bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    image = frame.image;

    final screenSize = MediaQuery.of(context).size;
    final imageAspectRatio = image!.width / image!.height;

    // Calculate the ideal size for fitting the image on the screen
    if (imageAspectRatio > screenSize.width / screenSize.height) {
      imageSize = Size(screenSize.width, screenSize.width / imageAspectRatio);
    } else {
      imageSize = Size(screenSize.height * imageAspectRatio, screenSize.height);
    }

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint();

    canvas.drawImageRect(
      image!,
      Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()),
      Rect.fromLTWH(0, 0, imageSize!.width, imageSize!.height),
      paint,
    );

    final recordedPicture = pictureRecorder.endRecording();
    resizedImage = await recordedPicture.toImage(
      imageSize!.width.round(),
      imageSize!.height.round(),
    );

    setState(() {});
  }

  void addPoint(Offset point) {
    setState(() {
      points.add(point);
    });
  }

  Future<void> saveDrawing() async {
    if (resizedImage == null || image == null) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(Offset.zero, Offset(imageSize!.width, imageSize!.height)),
    );
    final paint = Paint()..style = PaintingStyle.stroke;
    final pointPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 10.0;

    canvas.drawImageRect(
      image!,
      Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()),
      Rect.fromLTWH(0, 0, imageSize!.width, imageSize!.height),
      paint,
    );

    for (var point in points) {
      canvas.drawCircle(point, 10.0, pointPaint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(
        imageSize!.width.round(), imageSize!.height.round());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final buffer = byteData!.buffer.asUint8List();
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/drawn_image.png';
    final file = File(path);
    await file.writeAsBytes(buffer);

    setState(() {
      savedImage = file;
    });

    print("Saved to $path");
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Image saved to $path")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Draw on Image'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: saveDrawing,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: resizedImage == null
                  ? CircularProgressIndicator()
                  : GestureDetector(
                      onPanUpdate: (details) {
                        final RenderBox renderBox =
                            context.findRenderObject() as RenderBox;
                        final localPosition =
                            renderBox.globalToLocal(details.localPosition);
                        final imageRect = Rect.fromLTWH(
                            0, 0, imageSize!.width, imageSize!.height);

                        if (imageRect.contains(localPosition)) {
                          addPoint(localPosition);
                        }
                      },
                      child: CustomPaint(
                        painter: _DrawingPainter(points, resizedImage!),
                        child: Container(
                          width: imageSize!.width,
                          height: imageSize!.height,
                        ),
                      ),
                    ),
            ),
          ),
          if (savedImage != null)
            Container(
              padding: EdgeInsets.all(16.0),
              child: Image.file(savedImage!),
            ),
        ],
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<Offset> points;
  final ui.Image image;

  _DrawingPainter(this.points, this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10.0;

    canvas.drawImage(image, Offset.zero, Paint());

    for (final point in points) {
      canvas.drawCircle(point, 10.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
