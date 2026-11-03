import '../domain/entities.dart';
import '../domain/repositories.dart';
import 'data_support.dart';

class SupabaseAssistantRepository extends SupabaseAccess
    implements AssistantRepository {
  const SupabaseAssistantRepository(super.client);

  @override
  Future<List<ChatThread>> listThreads() => protect(() async {
    final owner = ownerId;
    final rows = await loadPages(
      (from, to) => client
          .from('chat_threads')
          .select()
          .eq('owner_id', owner)
          .order('updated_at', ascending: false)
          .order('id')
          .range(from, to),
    );
    return rows.map(threadFromJson).toList(growable: false);
  });

  @override
  Future<List<ChatMessage>> listMessages(String threadId) => protect(() async {
    final owner = ownerId;
    final rows = await loadPages(
      (from, to) => client
          .from('chat_messages')
          .select()
          .eq('owner_id', owner)
          .eq('thread_id', threadId)
          .order('created_at')
          .order('id')
          .range(from, to),
    );
    return rows.map(messageFromJson).toList(growable: false);
  });

  @override
  Future<ChatTurn> send({
    required String message,
    required AiMode mode,
    String? threadId,
    String? documentId,
  }) => protect(() async {
    ownerId;
    final response = await client.functions.invoke(
      'ai-chat',
      body: {
        'message': message.trim(),
        'mode': mode.name,
        if (threadId != null) 'thread_id': threadId,
        if (documentId != null) 'document_id': documentId,
      },
    );
    final row = jsonObject(response.data);
    return ChatTurn(
      threadId: row['thread_id'] as String,
      userMessage: messageFromJson(jsonObject(row['user_message'])),
      assistantMessage: messageFromJson(jsonObject(row['assistant_message'])),
    );
  });

  @override
  Future<void> deleteThread(String threadId) => protect(() async {
    await client
        .from('chat_threads')
        .delete()
        .eq('owner_id', ownerId)
        .eq('id', threadId);
  });
}
