import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Bounds of visible pixels, leaving every non-transparent brand pixel intact.
Rect visibleWordmarkBounds(Uint8List rgba, int width, int height) {
  var left=width, top=height, right=-1, bottom=-1;
  for(var y=0;y<height;y++) {
    for(var x=0;x<width;x++) {
      if(rgba[(y*width+x)*4+3] > 12) {
        if(x<left) left=x; if(x>right) right=x;
        if(y<top) top=y; if(y>bottom) bottom=y;
      }
    }
  }
  return right<left ? Rect.fromLTWH(0,0,width.toDouble(),height.toDouble())
      : Rect.fromLTRB(left.toDouble(),top.toDouble(),(right+1).toDouble(),(bottom+1).toDouble());
}

class WordmarkImage extends StatefulWidget {
  const WordmarkImage({required this.url,required this.width,required this.height,required this.fallback,super.key});
  final String url;
  final double width,height;
  final Widget fallback;
  @override
  State<WordmarkImage> createState()=>_WordmarkImageState();
}

class _WordmarkImageState extends State<WordmarkImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;
  Rect? _bounds;
  bool _failed=false;
  int _generation=0;
  @override
  void didChangeDependencies(){super.didChangeDependencies();_resolve();}
  @override
  void didUpdateWidget(WordmarkImage old){super.didUpdateWidget(old);if(old.url!=widget.url)_resolve();}
  void _resolve(){
    _stream?.removeListener(_listener!);
    final generation=++_generation;
    _failed=false;
    _image?.dispose();_image=null;_bounds=null;
    _stream=CachedNetworkImageProvider(widget.url).resolve(createLocalImageConfiguration(context));
    _listener=ImageStreamListener((info,_)async{
      final image=info.image.clone(); info.dispose();
      Rect bounds=Rect.fromLTWH(0,0,image.width.toDouble(),image.height.toDouble());
      try {
        if(image.width*image.height<=4000000){
          final bytes=await image.toByteData(format:ui.ImageByteFormat.rawRgba);
          if(bytes!=null) bounds=visibleWordmarkBounds(bytes.buffer.asUint8List(bytes.offsetInBytes,bytes.lengthInBytes),image.width,image.height);
        }
      }catch(_){/* Opaque images still render with their original proportions. */}
      if(!mounted||generation!=_generation){image.dispose();return;}
      setState((){_image?.dispose();_image=image;_bounds=bounds;});
    },onError:(Object error,StackTrace? stack){if(mounted&&generation==_generation)setState(()=>_failed=true);});
    _stream!.addListener(_listener!);
  }
  @override
  void dispose(){_generation++;_stream?.removeListener(_listener!);_image?.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>SizedBox(width:widget.width,height:widget.height,
    child:_failed?widget.fallback:_image==null?const SizedBox.shrink():CustomPaint(painter:_WordmarkPainter(_image!,_bounds!)));
}

class _WordmarkPainter extends CustomPainter {
  _WordmarkPainter(this.image,this.bounds);
  final ui.Image image;
  final Rect bounds;
  @override
  void paint(Canvas canvas,Size size){
    final fitted=applyBoxFit(BoxFit.contain,bounds.size,size);
    canvas.drawImageRect(image,bounds,Alignment.center.inscribe(fitted.destination,Offset.zero&size),Paint()..filterQuality=FilterQuality.high);
  }
  @override
  bool shouldRepaint(_WordmarkPainter old)=>old.image!=image||old.bounds!=bounds;
}
