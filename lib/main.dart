import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_charts/flutter_charts.dart';

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
  ChartData _chartData;
  ChartOptions _chartOptions;

  int get _overallToday => _measuredToday + _addedToday;
  String get _overallFormatted =>
      '${(_overallToday / 1000).toStringAsFixed(3)} l';

  void _initChart() {
    final double todayTarget = 100.0;
    double todayUsed = _overallToday / 1000;
    double todayRemaining = todayTarget - todayUsed;
    double todayOverflow = 0.0;
    if (todayUsed > todayTarget) {
      todayOverflow = todayUsed - todayTarget;
      todayRemaining = 0.0;
      todayUsed = todayTarget;
    }
    _chartData = new ChartData()
      ..dataRows = [
        [89.1, 100.0, todayUsed],
        [10.9, 0.0, todayRemaining],
        [0.0, 4.9, todayOverflow],
      ]
      ..dataRowsColors = [Colors.blue, Colors.blueGrey, Colors.red]
      ..xLabels = ['T-2', 'T-1', 'Today'];
    _chartOptions ??= new VerticalBarChartOptions();
  }

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
    _initChart();
    // This method is rerun every time setState is called.
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.title),
      ),
      body: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Text(
              'Today: $_overallFormatted',
              style: Theme.of(context).textTheme.display1,
            ),
            new Expanded(
                child: new Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                new Expanded(
                    child: new VerticalBarChart(
                  painter: new VerticalBarChartPainter(),
                  layouter: new VerticalBarChartLayouter(
                    chartData: _chartData,
                    chartOptions: _chartOptions,
                  ),
                ))
              ],
            )),
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
                              style: new TextStyle(color: Colors.red),
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
