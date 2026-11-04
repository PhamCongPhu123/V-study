import 'package:flutter/material.dart';
import '../domain/use_cases.dart';
import 'ai_page.dart';
import 'app_footer.dart';
import 'calendar_page.dart';
import 'design_system.dart';
import 'home_page.dart';
import 'quiz_page.dart';
import 'quiz_ai_launcher.dart';
import 'statistics_page.dart';
import 'draft_exit_scope.dart';
import 'widgets.dart';

/// A navigator per tab keeps the footer visible even on pushed feature screens.
class VstudyShell extends StatefulWidget {
  const VstudyShell({
    super.key,
    required this.useCases,
    this.preview = false,
    this.onPreviewSignOut,
  });
  final VstudyUseCases useCases;
  final bool preview;
  final VoidCallback? onPreviewSignOut;
  @override
  State<VstudyShell> createState() => _VstudyShellState();
}

class _VstudyShellState extends State<VstudyShell> {
  final _navigators = List.generate(6, (_) => GlobalKey<NavigatorState>());
  final _epochs = List.generate(6, (_) => ValueNotifier<int>(0));
  final _canHandleBack = List.filled(6, false);
  final _visited = <int>{2};
  int _index = 2;
  int _footerIndex = 2;
  String? _aiPrompt;
  DraftLeaveHandler? _draftLeave;
  bool _switchingTab = false;

  Future<void> _select(int index) async {
    if (_switchingTab) {
      return;
    }
    final leave = _draftLeave;
    if (leave != null) {
      _switchingTab = true;
      try {
        if (!await leave() || !mounted) {
          return;
        }
        _draftLeave = null;
      } catch (error) {
        if (mounted) {
          showError(context, error);
        }
        return;
      } finally {
        _switchingTab = false;
      }
    }
    if (!mounted) {
      return;
    }
    final repeat = _index == index;
    _navigators[index].currentState?.popUntil((route) => route.isFirst);
    // Re-entering home/stats/docs reloads data written in other tabs. Calendar
    // retains its selected day and view until explicitly reselected.
    if (_visited.contains(index) && (index != 0 || repeat)) {
      _epochs[index].value++;
    }
    setState(() {
      _visited.add(index);
      _index = index;
      _footerIndex = index;
    });
  }

  void _openAi(String? prompt) {
    if (prompt != null) {
      // Keep existing AI routes and their drafts. A supplied prompt opens a
      // new conversation above them, without sending it automatically.
      _aiPrompt = prompt;
      _epochs[5].value++;
    }
    setState(() {
      _visited.add(5);
      _index = 5;
    });
  }

  void _closeAi() => setState(() => _index = _footerIndex);

  @override
  void dispose() {
    for (final epoch in _epochs) {
      epoch.dispose();
    }
    super.dispose();
  }

  Widget _page(int index) => switch (index) {
    0 => CalendarPage(useCases: widget.useCases),
    1 => QuizPage(useCases: widget.useCases),
    2 => HomePage(
      useCases: widget.useCases,
      onNavigate: _select,
      preview: widget.preview,
      onPreviewSignOut: widget.onPreviewSignOut,
    ),
    3 => StatisticsPage(useCases: widget.useCases),
    4 => DocumentsPage(useCases: widget.useCases),
    _ => AiPage(
      useCases: widget.useCases,
      initialPrompt: _aiPrompt,
      preview: widget.preview,
      onClose: _closeAi,
      promptVersion: _epochs[5].value,
    ),
  };

  Widget _tab(int index) {
    if (!_visited.contains(index)) {
      return const SizedBox.shrink();
    }
    return NotificationListener<NavigationNotification>(
      onNotification: (notification) {
        if (_canHandleBack[index] != notification.canHandlePop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _canHandleBack[index] = notification.canHandlePop);
            }
          });
        }
        return true;
      },
      child: Navigator(
        key: _navigators[index],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ValueListenableBuilder<int>(
            valueListenable: _epochs[index],
            builder: (_, epoch, _) => KeyedSubtree(
              key: ValueKey(index == 5 ? 'ai-root' : '$index-$epoch'),
              child: _page(index),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DraftExitScope(
    attach: (handler) {
      _draftLeave = handler;
      return () {
        if (_draftLeave == handler) {
          _draftLeave = null;
        }
      };
    },
    child: QuizAiLauncher(
      onOpen: _openAi,
      child: PopScope<Object?>(
        canPop: _index == 2 && !_canHandleBack[_index],
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }
          if (_canHandleBack[_index]) {
            _navigators[_index].currentState?.maybePop(result);
          } else if (_index == 5) {
            _closeAi();
          } else if (_index != 2) {
            _select(2);
          }
        },
        child: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: VstudyColors.background),
            child: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _index,
                children: List.generate(6, _tab),
              ),
            ),
          ),
          bottomNavigationBar: VstudyFooter(
            selectedIndex: _footerIndex,
            onSelected: _select,
          ),
          floatingActionButton: _index != 5
              ? FloatingActionButton.small(
                  key: const ValueKey('open-ai'),
                  tooltip: 'Hỏi trợ lý V-study',
                  onPressed: () => _openAi(null),
                  child: const Icon(Icons.auto_awesome),
                )
              : null,
        ),
      ),
    ),
  );
}
