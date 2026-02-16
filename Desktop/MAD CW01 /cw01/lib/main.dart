import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const CounterImageToggleApp());

class CounterImageToggleApp extends StatefulWidget {
  const CounterImageToggleApp({super.key});

  @override
  State<CounterImageToggleApp> createState() => _CounterImageToggleAppState();
}

class _CounterImageToggleAppState extends State<CounterImageToggleApp> {
  bool _isDark = false;

  void _toggleTheme() => setState(() => _isDark = !_isDark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CW1 Counter & Toggle',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(
        isDark: _isDark,
        onToggleTheme: _toggleTheme,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _ActionType { inc, dec, reset }

class _CounterAction {
  _CounterAction({
    required this.type,
    required this.delta,
    required this.prevValue,
    required this.newValue,
    required this.timestamp,
  });

  final _ActionType type;
  final int delta;
  final int prevValue;
  final int newValue;
  final DateTime timestamp;

  String get label {
    switch (type) {
      case _ActionType.inc:
        return "+$delta → $newValue";
      case _ActionType.dec:
        return "-${delta.abs()} → $newValue";
      case _ActionType.reset:
        return "Reset → $newValue";
    }
  }
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _counter = 0;
  final List<int> _steps = [1, 5, 10];
  int _step = 1;

  final TextEditingController _goalController = TextEditingController();
  int _goal = 10;
  bool _celebrated = false;

  final List<_CounterAction> _history = [];
  SharedPreferences? _prefs;

  bool _isFirstImage = true;

  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        _isFirstImage = true;
        _saveState();
      } else if (status == AnimationStatus.completed) {
        _isFirstImage = false;
        _saveState();
      }
      setState(() {});
    });

    _loadState();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    _prefs = await SharedPreferences.getInstance();

    final savedCounter = _prefs!.getInt('counter') ?? 0;
    final savedStep = _prefs!.getInt('step') ?? 1;
    final savedGoal = _prefs!.getInt('goal') ?? 10;
    final savedIsFirst = _prefs!.getBool('isFirstImage') ?? true;

    setState(() {
      _counter = savedCounter;
      _step = _steps.contains(savedStep) ? savedStep : 1;
      _goal = savedGoal > 0 ? savedGoal : 10;
      _goalController.text = _goal.toString();
      _celebrated = _counter >= _goal;

      _isFirstImage = savedIsFirst;
      _controller.value = _isFirstImage ? 0.0 : 1.0;
    });
  }

  Future<void> _saveState() async {
    final p = _prefs;
    if (p == null) return;
    await p.setInt('counter', _counter);
    await p.setInt('step', _step);
    await p.setInt('goal', _goal);
    await p.setBool('isFirstImage', _isFirstImage);
  }

  void _addHistory(_CounterAction action) {
    _history.insert(0, action);
    if (_history.length > 5) _history.removeLast();
  }

  void _applyCounterChange({
    required _ActionType type,
    required int newValue,
    required int delta,
  }) {
    final prev = _counter;

    setState(() {
      _counter = newValue;

      _addHistory(
        _CounterAction(
          type: type,
          delta: delta,
          prevValue: prev,
          newValue: newValue,
          timestamp: DateTime.now(),
        ),
      );

      final reached = _goal > 0 && _counter >= _goal;
      if (reached && !_celebrated) {
        _celebrated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Goal reached!')),
          );
        });
      }
      if (_goal > 0 && _counter < _goal) _celebrated = false;
    });

    _saveState();
  }

  void _setStep(int step) {
    setState(() => _step = step);
    _saveState();
  }

  void _incrementCounter() {
    _applyCounterChange(
      type: _ActionType.inc,
      newValue: _counter + _step,
      delta: _step,
    );
  }

  void _decrementCounter() {
    if (_counter == 0) return;
    final next = _counter - _step;
    _applyCounterChange(
      type: _ActionType.dec,
      newValue: next < 0 ? 0 : next,
      delta: -_step,
    );
  }

  Future<void> _showResetDialog() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Reset'),
        content: const Text(
          'Are you sure you want to clear all saved data? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      await _resetAppData();
    }
  }

  Future<void> _resetAppData() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.remove('counter');
    await p.remove('step');
    await p.remove('goal');
    await p.remove('isFirstImage');

    setState(() {
      _counter = 0;
      _step = 1;
      _goal = 10;
      _goalController.text = '10';
      _celebrated = false;

      _isFirstImage = true;
      _controller.value = 0.0;

      _history.clear();
    });

    await _saveState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset complete')),
      );
    }
  }

  void _undoLast() {
    if (_history.isEmpty) return;
    final last = _history.removeAt(0);

    setState(() {
      _counter = last.prevValue;
      if (_goal > 0 && _counter < _goal) _celebrated = false;
    });

    _saveState();
  }

  void _setGoalFromInput() {
    final raw = _goalController.text.trim();
    final parsed = int.tryParse(raw);

    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid goal.')),
      );
      return;
    }

    setState(() {
      _goal = parsed;
      _celebrated = _counter >= _goal;
    });
    _saveState();
  }

  double get _progress {
    if (_goal <= 0) return 0.0;
    final p = _counter / _goal;
    if (p < 0) return 0.0;
    if (p > 1) return 1.0;
    return p;
  }

  void _toggleImage() {
    if (_isFirstImage) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDecrement = _counter > 0;
    final canUndo = _history.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CW1 Counter & Toggle'),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Counter: $_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _incrementCounter,
                child: Text('Increment (+$_step)'),
              ),
              const SizedBox(height: 14),
              Text('Step: +$_step',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _steps
                    .map(
                      (v) => ChoiceChip(
                        label: Text("+$v"),
                        selected: v == _step,
                        onSelected: (_) => _setStep(v),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton(
                    onPressed: canDecrement ? _decrementCounter : null,
                    child: Text('Decrement (-$_step)'),
                  ),
                  FilledButton.tonal(
                    onPressed: _showResetDialog,
                    child: const Text('RESET'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Goal Meter',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _goalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Set goal',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _setGoalFromInput(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _setGoalFromInput,
                    child: const Text('Set'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(
                  'Progress: $_counter / $_goal (${(_progress * 100).round()}%)'),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('History + Undo',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: canUndo ? _undoLast : null,
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      canUndo
                          ? 'Last: ${_history.first.label}'
                          : 'No actions yet',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _history.isEmpty
                    ? const Text('—')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _history
                            .map((a) => Text('• ${a.label}'))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Task 2: Image Toggle & Animation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FadeTransition(
                      opacity: ReverseAnimation(_anim),
                      child: Image.asset('assets/fortress.jpg',
                          fit: BoxFit.cover),
                    ),
                    FadeTransition(
                      opacity: _anim,
                      child: Image.asset('assets/fortress1.jpg',
                          fit: BoxFit.cover),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _toggleImage,
                child: const Text('Toggle Image'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
