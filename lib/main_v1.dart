import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'WaterFlow Target',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'WaterFlow'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage({Key key, this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Timer _timer;
  double _initialMeasurement;
  int _measuredToday = 0;
  int _addedToday = 0;

  int get _overallToday => _measuredToday + _addedToday;
  String get _overallFormatted =>
      '${(_overallToday / 1000).toStringAsFixed(3)} l';

  void _add(int millis) {
    int remaining = millis;
    new Timer.periodic(new Duration(milliseconds: 100), (Timer timer) {
      int adding = millis ~/ 19;
      if (adding > remaining) {
        adding = remaining;
      }
      setState(() {
        _addedToday += adding;
        remaining -= adding;
      });
      if (remaining == 0) {
        timer.cancel();
      }
    });
  }

  void _startPolling() {
    if (_timer != null) return;
    setState(() {
      _timer = new Timer.periodic(new Duration(seconds: 1), (_) => _update());
    });
  }

  void _stopPolling() {
    if (_timer == null) return;
    setState(() {
      _timer.cancel();
      _timer = null;
    });
  }

  void _reset() {
    setState(() {
      _addedToday = 0;
      _initialMeasurement = null;
    });
  }

  Future _update() async {
    try {
      String content = (await get('http://10.3.2.188:5000/')).body;
      Map map = JSON.decode(content);
      double currentMeasurement = map['millilitre_count'];
      if (_initialMeasurement == null ||
          _initialMeasurement > currentMeasurement) {
        _initialMeasurement = currentMeasurement;
      }
      setState(() {
        _measuredToday = (currentMeasurement - _initialMeasurement).round();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called.
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.title),
      ),
      body: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            new Text(
              'Today: $_overallFormatted',
              style: Theme.of(context).textTheme.display1,
            ),
            new Column(
              children: <Widget>[
                new Row(
                  children: <Widget>[
                    new RaisedButton(
                        child: new Text('2 dl'), onPressed: () => _add(200)),
                    new RaisedButton(
                        child: new Text('1 l'), onPressed: () => _add(1000)),
                    new RaisedButton(
                        child: new Text('5 l'), onPressed: () => _add(5000)),
                    new RaisedButton(
                        child: new Text('20 l'), onPressed: () => _add(20000)),
                  ],
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                ),
                new Row(
                  children: <Widget>[
                    new RaisedButton(
                        child: new Text('Reset'), onPressed: _reset),
                    _timer == null
                        ? new RaisedButton(
                            child: new Text(
                              'Start Monitoring',
                              style: new TextStyle(
                                  color: new Color.fromRGBO(255, 0, 0, 1.0)),
                            ),
                            onPressed: _startPolling)
                        : new RaisedButton(
                            child: new Text('Stop Monitoring'),
                            onPressed: _stopPolling),
                  ],
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
