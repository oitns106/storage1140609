
import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:storage1140609/firebase_options.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Storage Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Storage Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  
  var storage=FirebaseStorage.instance;
  List<AssetImage> listOfImage=[];
  List<String> listOfStr=[];
  bool clicked=false;
  bool isLoading=false;
  String? images;
  late Future<ListResult> futureFiles;
  
  @override
  void initState() {
    getImages();
    futureFiles=FirebaseStorage.instance.ref('/images').listAll();
    super.initState();
  }
  
  void getImages() {
    listOfImage=[];
    for (int i=0; i<6; i++) {
      listOfImage.add(AssetImage('assets/travelimage' + i.toString() + '.jpeg'));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title),),
      body: Container(
        child: Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.all(0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
              ),
              itemCount: listOfImage.length,
              itemBuilder: (context, index) {
                return GridTile(
                  child: Material(
                    child: GestureDetector(
                      child: Stack(
                        children: [
                          this.images==listOfImage[index].assetName || listOfStr.contains(listOfImage[index].assetName)?
                              Positioned.fill(child: Opacity(
                                  opacity: 0.7, child: Image.asset(listOfImage[index].assetName, fit: BoxFit.fill,)))
                              :Positioned.fill(child: Opacity(
                              opacity: 1.0, child: Image.asset(listOfImage[index].assetName, fit: BoxFit.fill,))),
                          this.images==listOfImage[index].assetName || listOfStr.contains(listOfImage[index].assetName)?
                              Positioned(left: 0, bottom: 0, child: Icon(Icons.check_circle, color: Colors.green),)
                              :Visibility(visible:false, child: Icon(Icons.check_circle_outline, color: Colors.black),),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          if (listOfStr.contains(listOfImage[index].assetName)) {
                            this.clicked=false;
                            listOfStr.remove(listOfImage[index].assetName);
                            this.images=null;
                          }
                          else {
                            this.clicked=true;
                            this.images=listOfImage[index].assetName;
                            listOfStr.add(this.images!);
                          }
                        });
                      },
                    ),
                  ),
                );
              },
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  this.isLoading=true;
                });
                listOfStr.forEach((img) async {
                  String imageName=img.substring(img.lastIndexOf('/'), img.lastIndexOf('.')).replaceAll('/', '');
                  final Directory systemTempDir=Directory.systemTemp;
                  final byteData=await rootBundle.load(img);
                  final file=File('${systemTempDir.path}/$imageName.jpeg');
                  await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
                  
                  TaskSnapshot snapshot=await storage.ref().child('image/$imageName').putFile(file);
                  if (snapshot.state==TaskState.success) {
                    final String downloadUrl=await snapshot.ref.getDownloadURL();
                    await FirebaseFirestore.instance.collection('image').add({'url': downloadUrl, 'name': imageName});
                    setState(() {
                      this.isLoading=false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully loaded!')));
                  }
                  else {
                    throw 'Failed to load...';
                  }   
                });
              }, 
              child: Text('Save Images'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context)=>SecondPage()));
              }, 
              child: Text('Get Images'),
            ),
            isLoading? CircularProgressIndicator():Visibility(visible: false, child: Text('test'),),
          ],
        ),
      ),
    );
  }
}

class SecondPage extends StatefulWidget {
  const SecondPage({super.key});

  @override
  State<SecondPage> createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {

  final FirebaseFirestore fss=FirebaseFirestore.instance;
  File? image;
  bool isLoading=false;
  bool isRetrieved=false;
  QuerySnapshot<Map<String, dynamic>>? cachedResult;

  Future<QuerySnapshot<Map<String, dynamic>>> getImages() {
    return fss.collection('image').get();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Second Page'),
                       centerTitle: true,),
        body: Container(
          padding: EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: Column(
              children: [
                FutureBuilder(
                  future: getImages(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState==ConnectionState.done) {
                      isRetrieved=true;
                      cachedResult=snapshot.data;
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            contentPadding: EdgeInsets.all(8),
                            title: Text(snapshot.data!.docs[index].data()['name']),
                            leading: Image.network(snapshot.data!.docs[index].data()['url'], fit: BoxFit.fill,),
                            trailing: IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                FirebaseFirestore.instance.collection('image').doc(snapshot.data!.docs[index].id).delete();
                                FirebaseStorage.instance.refFromURL(snapshot.data!.docs[index].data()['url']).delete();
                              },
                            ),
                          );
                        },
                      );
                    }
                    else if (snapshot.connectionState==ConnectionState.none) {
                      return Text('No data!');
                    }
                    return CircularProgressIndicator();
                  },
                ),
                ElevatedButton(
                  child: Text('Pick Image'),
                  onPressed: () async {
                    final picker=ImagePicker();
                    var image1=await picker.pickImage(source: ImageSource.gallery);
                    setState(() {
                      image=File(image1!.path);
                    });
                  },
                ),
                image==null? Text('No image selected.')
                             : Image.file(image!, fit: BoxFit.fill, height: 300),
                !isLoading? ElevatedButton(
                              onPressed: () async {
                                if (image!=null) {
                                  setState(() {
                                    isLoading=true;
                                  });
                                  Reference ref=FirebaseStorage.instance.ref();
                                  String formattedDate=DateFormat('yyyyMMddHHMMSS').format(DateTime.now());
                                  TaskSnapshot addImg=await ref.child('image/'+formattedDate).putFile(image!);
                                  if (addImg.state==TaskState.success) {
                                    setState(() {
                                      this.isLoading=false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully added to Firebase Storage!')));
                                  }
                                  final imageUrl=await ref.child('image/'+formattedDate).getDownloadURL();
                                  Navigator.push(context, MaterialPageRoute(builder: (context)=>ThirdPage()));
                                }
                              },
                              child: Text('Save Image'),
                            )
                            : CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

late VideoPlayerController controller;
late Future<void> _video;

class ThirdPage extends StatefulWidget {
  const ThirdPage({super.key});

  @override
  State<ThirdPage> createState() => _ThirdPageState();
}

class _ThirdPageState extends State<ThirdPage> {
  
  PlatformFile? pickFile;
  UploadTask? uploadTask;
  
  Future uploadFile() async {
    final path='files/${pickFile!.name}';
    final file=File(pickFile!.path!);
    
    final ref=FirebaseStorage.instance.ref().child(path);
    setState(() {
      uploadTask=ref.putFile(file);
    });
    
    final snapshot=await uploadTask!.whenComplete(() {
      Navigator.push(context, MaterialPageRoute(builder: (context)=>FourthPage()));
    });
    
    final urlDownload=await snapshot.ref.getDownloadURL();
    print('Download link: $urlDownload');
    
    setState(() {
      uploadTask=null;
    });
  }
  
  Future selectFile() async {
    final result=await FilePicker.platform.pickFiles();
    if (result==null) return;
    setState(() {
      pickFile=result.files.first;
      final file=File(pickFile!.path!);
      switch (pickFile!.extension!.toLowerCase()) {
        case 'jpg':
        case 'jpeg':
        case 'png': Image.file(file, width: double.infinity, fit: BoxFit.cover,);
        case 'mp4': VideoPlayerWidget(file: file);
        default: Center(child: Text(pickFile!.name));
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload File'),),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (pickFile!=null) 
              Expanded(
                child: Container(
                  color: Colors.blue,
                  child: Text(""),
                ),
              ),
            SizedBox(height: 32,),
            Text(pickFile==null? "Hello":pickFile!.name),
            ElevatedButton(
              child: Text('Select File'),
              onPressed: selectFile, 
            ),
            SizedBox(height: 32,),
            ElevatedButton(
              child: Text('Upload File'),
              onPressed: uploadFile,
            ),
            SizedBox(height: 32,),
            StreamBuilder(
              stream: uploadTask?.snapshotEvents,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final data=snapshot.data!;
                  double progress=data.bytesTransferred / data.totalBytes;
                  return SizedBox(
                    height: 50,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey,
                          color: Colors.green,
                        ),
                        Center(
                          child: Text('${(100*progress).roundToDouble()}%',
                                       style: TextStyle(color: Colors.white),),
                        ),
                      ],
                    ),
                  );
                }
                else {
                  return SizedBox(height: 50,);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  File file;
  VideoPlayerWidget({super.key, required this.file,});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  
  @override
  void initState() {
    controller=VideoPlayerController.file(widget.file);
    _video=controller.initialize();
    super.initState();
  }
  
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    controller=VideoPlayerController.file(widget.file)
               ..addListener(()=>setState(() {}))
               ..setLooping(true)
               ..initialize();
    
    return !controller.value.isInitialized? Container(height: 200, child: Center(child: CircularProgressIndicator()),)
        : Container(width: double.infinity, child: AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)));
  }
}


class FourthPage extends StatefulWidget {
  const FourthPage({super.key});

  @override
  State<FourthPage> createState() => _FourthPageState();
}

class _FourthPageState extends State<FourthPage> {

  late Future<ListResult> futureFiles;
  Map<int, double> downloadProgress={};
  String? urlPreview;
  int selectedIndex=0;

  @override
  void initState() {
    futureFiles=FirebaseStorage.instance.ref('/files').listAll();
    futureFiles.then((files) {
      if (files.items.isNotEmpty) {
        setPreview(0, files.items.first);
      }
    });
    super.initState();
  }

  Future setPreview(int index, Reference file) async {
    final urlFile=await file.getDownloadURL();
    setState(() {
      selectedIndex=index;
      urlPreview=urlFile;
    });
  }

  Widget buildPreview() {
    if (urlPreview!=null) {
      if (urlPreview!.contains('.jpg')) {
        return Image.network(
          urlPreview!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      }
      else if (urlPreview!.contains('.mp4')) {
        return VideoPlayerWidget1(key: Key(urlPreview!),
                                  url: urlPreview!);
      }
    }
    return Center(child: Text('No preview.'),);
  }

  Future downloadFile(int index, Reference ref) async {
    final url=await ref.getDownloadURL();
    final tempDir=await getTemporaryDirectory();
    final path='${tempDir.path}/${ref.name}';
    await Dio().download(url, path,
                         onReceiveProgress: (received, total) {
                           double progress=received/total;
                           setState(() {
                             downloadProgress[index]=progress;
                           });
                         });
    if (url.contains('.mp4')) {
      await GallerySaver.saveVideo(path, toDcim: true);
    }
    else if (url.contains('.jpg')) {
      await GallerySaver.saveImage(path, toDcim: true);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded ${ref.name}')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Download Files'),),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.blue,
            height: 300,
            child: buildPreview(),
          ),
          FutureBuilder(
            future: futureFiles,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final files=snapshot.data!.items;
                return Expanded(
                  child: ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file=files[index];
                      final isSelected=index==selectedIndex;
                      final progress=downloadProgress[index];
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Colors.blue,
                        title: Text(file.name, style: TextStyle(color: Colors.black,
                                                                fontWeight: isSelected? FontWeight.bold : FontWeight.normal),),
                        subtitle: progress!=null? LinearProgressIndicator(value: progress, backgroundColor: Colors.black26,): null,
                        trailing: IconButton(
                          onPressed: ()=>downloadFile(index, file),
                          icon: Icon(Icons.download, color: Colors.black,),
                        ),
                        onTap: ()=>setPreview(index, file),
                      );
                    },
                  ),
                );
              }
              else if (snapshot.hasError) {
                return Center(child: Text('Error occurred!'),);
              }
              else {
                return Center(child: CircularProgressIndicator(),);
              }
            },
          ),
        ],
      ),
    );
  }
}

class VideoPlayerWidget1 extends StatefulWidget{
  final String url;
  const VideoPlayerWidget1({super.key, required this.url});

  @override
  State<VideoPlayerWidget1> createState() => _VideoPlayerWidget1State();
}

class _VideoPlayerWidget1State extends State<VideoPlayerWidget1> {
  late VideoPlayerController controller;

  @override
  void initState() {
    controller=VideoPlayerController.networkUrl(Uri.parse(widget.url))
    ..addListener(()=>setState(() {}))
    ..setLooping(true)
    ..initialize().then((_)=>controller.play());
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return !controller.value.isInitialized?
        Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              color: Colors.blue,
              strokeWidth: 5,
            ),
          ),
        ):
        SizedBox(
          width: double.infinity,
          child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
          ),
        );
  }
}



