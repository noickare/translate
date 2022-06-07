import 'dart:async';

import 'package:avatar_glow/avatar_glow.dart';
import 'package:client/models/message.dart';
import 'package:clipboard/clipboard.dart';
// import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_speech/google_speech.dart';
import 'package:rxdart/rxdart.dart';
import 'package:search_choices/search_choices.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../main.dart';

class ConversationScreen extends StatefulWidget {
  final String uid;
  const ConversationScreen({Key? key, required this.uid}) : super(key: key);

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  // String text = 'Press the button and start speaking';
  // bool isListening = false;

  final RecorderStream _recorder = RecorderStream();
  List<DropdownMenuItem> languages = [];

  bool recognizing = false;
  bool recognizeFinished = false;
  String? selectedLanguage;
  String text = '';
  StreamSubscription<List<int>>? _audioStreamSubscription;
  BehaviorSubject<List<int>>? _audioStream;
  final List<MessageModel> _messages = [];
  CollectionReference conversation =
      FirebaseFirestore.instance.collection('conversations');
  var uuid = Uuid();

  void setStateIfMounted(f) {
    if (mounted) setState(f);
  }

  @override
  void initState() {
    super.initState();

    _recorder.initialize();
  }

  RecognitionConfig _getConfig() => RecognitionConfig(
      encoding: AudioEncoding.LINEAR16,
      model: RecognitionModel.basic,
      enableAutomaticPunctuation: true,
      sampleRateHertz: 16000,
      languageCode: 'en-US');

  void streamingRecognize() async {
    _audioStream = BehaviorSubject<List<int>>();
    _audioStreamSubscription = _recorder.audioStream.listen((event) {
      _audioStream!.add(event);
    });

    await _recorder.start();

    setState(() {
      recognizing = true;
    });

    final serviceAccount = ServiceAccount.fromString(
        (await rootBundle.loadString('assets/gcloud.json')));

    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);

    final config = _getConfig();

    final responseStream = speechToText.streamingRecognize(
        StreamingRecognitionConfig(config: config, interimResults: true),
        _audioStream!);

    var responseText = '';

    responseStream.listen((data) {
      final currentText =
          data.results.map((e) => e.alternatives.first.transcript).join('\n');

      if (data.results.first.isFinal) {
        responseText += '\n' + currentText;

        setState(() {
          text = responseText;
          recognizeFinished = true;
        });
      } else {
        setState(() {
          text = responseText + '\n' + currentText;
          recognizeFinished = true;
        });
      }
    }, onDone: () {
      setState(() {
        recognizing = false;
      });
    });
  }

  void stopRecording() async {
    if (recognizing) {
      await _recorder.stop();
      await _audioStreamSubscription?.cancel();
      await _audioStream?.close();
      setState(() {
        recognizing = false;
      });
    } else {
      streamingRecognize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(MyApp.title),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.content_copy),
              onPressed: () {
                FlutterClipboard.copy(text);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Copied to clipboard")));
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        reverse: true,
        padding: const EdgeInsets.all(30).copyWith(bottom: 150),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            SearchChoices.single(
              items: languages,
              value: selectedLanguage,
              hint: "Select one",
              searchHint: "Select one",
              onChanged: (value) {
                setState(() {
                  selectedLanguage = value;
                });
              },
              isExpanded: true,
            ),
            const Divider(),
            if (recognizeFinished)
              _RecognizeContent(
                text: text,
              ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AvatarGlow(
        animate: recognizing,
        endRadius: 75,
        glowColor: Theme.of(context).primaryColor,
        child: FloatingActionButton(
          onPressed: recognizing ? stopRecording : streamingRecognize,
          child: Icon(recognizing ? Icons.mic : Icons.mic_none, size: 36),
        ),
      ),
    );
  }
}

class _RecognizeContent extends StatelessWidget {
  final String? text;

  const _RecognizeContent({Key? key, this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          // const Text(
          //   'The text recognized by the Google Speech Api:',
          // ),
          const SizedBox(
            height: 16.0,
          ),
          Text(
            text ?? '---',
            style: Theme.of(context).textTheme.bodyText1,
          ),
        ],
      ),
    );
  }
}
