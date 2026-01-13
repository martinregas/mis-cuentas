
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'import_controller.dart';

class ShareHandler extends ConsumerStatefulWidget {
  final Widget child;
  const ShareHandler({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<ShareHandler> createState() => _ShareHandlerState();
}

class _ShareHandlerState extends ConsumerState<ShareHandler> {
  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    // For sharing files
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
        _handleSharedFiles(value);
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // Get the media intent that launched the app
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      _handleSharedFiles(value);
    });
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isNotEmpty) {
      for (var file in files) {
        if (file.path.endsWith('.pdf')) {
          // Improve: Handle multiple files? For now just one or loop.
          // We call the controller to import.
          ref.read(importControllerProvider.notifier).importPdf(File(file.path));
        }
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
