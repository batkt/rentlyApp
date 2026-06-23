import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/app_loading.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final ConversationModel? conversation;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _recorder = Record();

  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  String? _recordPath;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await ref.read(messagesProvider(widget.conversationId).notifier).send(text);
    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (picked == null) return;
      final file = File(picked.path);
      final text = _messageController.text.trim();
      _messageController.clear();
      await ref
          .read(messagesProvider(widget.conversationId).notifier)
          .sendWithImage(file, text: text.isEmpty ? null : text);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Зураг сонгоход алдаа гарлаа'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Микрофоны эрх олгоно уу'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        path: _recordPath!,
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
      );
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });
      _tickDuration();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Дуу бичихэд алдаа гарлаа'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _tickDuration() async {
    while (_isRecording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isRecording) break;
      setState(() => _recordDuration += const Duration(seconds: 1));
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) return;
    await ref
        .read(messagesProvider(widget.conversationId).notifier)
        .sendWithAudio(file);
    _scrollToBottom();
  }

  Future<void> _cancelRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
      _recordPath = null;
    });
    if (path != null) {
      try { await File(path).delete(); } catch (_) {}
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width > 600 ? 560 : double.infinity,
      ),
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appCardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.appDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              ),
              title: const Text('Зургийн цомгоос', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Хадгалсан зураг сонгох'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: AppColors.info),
              ),
              title: const Text('Камер', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Шинэ зураг авах'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesProvider(widget.conversationId));
    final agentName = state.messages
        .where((m) => !m.isFromUser && m.ajiltanNer != null && m.ajiltanNer!.isNotEmpty)
        .lastOrNull
        ?.ajiltanNer;
    final name = agentName ?? 'Захиргаа';

    ref.listen(messagesProvider(widget.conversationId), (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.success,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'З',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Text('Онлайн', style: TextStyle(fontSize: 11, color: AppColors.success)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(builder: (context) {
              if (state.isLoading && state.messages.isEmpty) return const AppLoading();
              if (state.messages.isEmpty) {
                return const AppEmpty(
                  icon: Icons.chat_bubble_outline_rounded,
                  message: 'Мессеж байхгүй байна',
                  subMessage: 'Эхний мессежийг илгээнэ үү',
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: state.messages.length,
                itemBuilder: (context, index) {
                  final message = state.messages[index];
                  final isMine = message.isFromUser;
                  final showDate = index == 0 ||
                      _isDifferentDay(state.messages[index - 1].createdAt, message.createdAt);
                  return Column(
                    children: [
                      if (showDate) _DateDivider(date: message.createdAt),
                      _MessageBubble(message: message, isMine: isMine),
                    ],
                  );
                },
              );
            }),
          ),
          if (state.error != null)
            Container(
              color: context.appErrorLight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(state.error!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error)),
                  ),
                ],
              ),
            ),
          _buildInputBar(state),
        ],
      ),
    );
  }

  bool _isDifferentDay(String? prev, String? curr) {
    if (prev == null || curr == null) return true;
    try {
      final d1 = DateTime.parse(prev);
      final d2 = DateTime.parse(curr);
      return d1.day != d2.day || d1.month != d2.month || d1.year != d2.year;
    } catch (_) {
      return false;
    }
  }

  Widget _buildInputBar(MessagesState state) {
    if (_isRecording) {
      return _buildRecordingBar();
    }
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(top: BorderSide(color: context.appDivider)),
      ),
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: state.isSending ? null : _showAttachmentOptions,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appInputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appDivider),
              ),
              child: Icon(
                Icons.attach_file_rounded,
                color: state.isSending ? context.appTextTertiary : AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.appInputFill,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.appDivider),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Мессеж бичих...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: false,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Voice record button (hold to record)
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopAndSendRecording(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.appInputFill,
                shape: BoxShape.circle,
                border: Border.all(color: context.appDivider),
              ),
              child: Icon(
                Icons.mic_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: state.isSending ? null : _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: state.isSending ? context.appTextTertiary : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: state.isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar() {
    final mins = _recordDuration.inMinutes.toString().padLeft(2, '0');
    final secs = (_recordDuration.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(top: BorderSide(color: AppColors.error.withOpacity(0.3))),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appErrorLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_rounded, color: AppColors.error, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$mins:$secs',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Бичиж байна...', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _stopAndSendRecording,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.success,
              child: Text(
                (message.ajiltanNer?.isNotEmpty == true)
                    ? message.ajiltanNer![0].toUpperCase()
                    : 'З',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : context.appCardBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: isMine ? null : Border.all(color: context.appDivider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.hasImage)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        message.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: context.appInputFill,
                          child: const Icon(Icons.broken_image_rounded, color: AppColors.textTertiary),
                        ),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                height: 120,
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                      ),
                    ),
                  if (message.hasAudio)
                    _AudioBubble(audioUrl: message.audioUrl!, isMine: isMine),
                  if (message.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: isMine ? Colors.white : context.appTextPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Text(
                      message.createdAt != null ? AppFormatters.dateTime(message.createdAt) : '',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMine ? Colors.white60 : context.appTextTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _AudioBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMine;

  const _AudioBubble({required this.audioUrl, required this.isMine});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final total = _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final pos = _position.inSeconds.toDouble().clamp(0.0, total);
    final color = widget.isMine ? Colors.white : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMine
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: color,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: color,
                    inactiveTrackColor: color.withOpacity(0.3),
                    thumbColor: color,
                    overlayColor: color.withOpacity(0.15),
                  ),
                  child: Slider(
                    value: pos,
                    min: 0,
                    max: total,
                    onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
                  ),
                ),
                Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final String? date;

  const _DateDivider({this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              date != null ? AppFormatters.date(date) : '',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.appTextTertiary),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
