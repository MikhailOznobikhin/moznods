import { useEffect, useRef, useCallback } from 'react';
import { useChatStore } from '../../store/useChatStore';
import { useAuthStore } from '../../store/useAuthStore';
import { MessageItem } from './MessageItem'; // Import the new component

export const MessageList = () => {
  const { messages, isLoading, markAsRead } = useChatStore();
  const { user: currentUser } = useAuthStore();
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const readMessagesRef = useRef(new Set<number>());

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleMessageVisible = useCallback((messageId: number) => {
    if (!currentUser) return;

    const message = messages.find(m => m.id === messageId);
    if (!message) return;

    const isReadByMe = message.read_by_ids?.includes(currentUser.id);
    if (!isReadByMe && message.author.id !== currentUser.id && !readMessagesRef.current.has(messageId)) {
      markAsRead(messageId);
      readMessagesRef.current.add(messageId); // Mark as sent for reading
    }
  }, [messages, currentUser, markAsRead]);

  if (isLoading && messages.length === 0) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="flex-1 overflow-y-auto p-4 space-y-4">
      {messages.map((message) => {
        const isOwn = message.author.id === currentUser?.id;
        const isReadByOthers = (message.read_by_ids?.length || 0) > (isOwn ? 0 : 1);

        return (
          <MessageItem 
            key={message.id} 
            message={message} 
            isOwn={isOwn} 
            isReadByOthers={isReadByOthers} 
            onVisible={handleMessageVisible}
          />
        );
      })}
      <div ref={messagesEndRef} />
    </div>
  );
};
