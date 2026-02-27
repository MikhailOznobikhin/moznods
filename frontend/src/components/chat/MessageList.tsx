import React, { useEffect, useRef } from 'react';
import { useChatStore } from '../../store/useChatStore';
import { useAuthStore } from '../../store/useAuthStore';
import { FileText } from 'lucide-react';
import { Avatar } from '../ui/Avatar';

export const MessageList = () => {
  const { messages, isLoading } = useChatStore();
  const { user: currentUser } = useAuthStore();
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

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

        return (
          <div
            key={message.id}
            className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}
          >
            <div
              className={`flex max-w-[70%] ${
                isOwn ? 'flex-row-reverse' : 'flex-row'
              } gap-3`}
            >
              <div className="flex-shrink-0">
                <Avatar user={message.author} size="sm" />
              </div>

              <div
                className={`flex flex-col ${
                  isOwn ? 'items-end' : 'items-start'
                }`}
              >
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-sm font-medium text-white">
                    {message.author.display_name || message.author.username}
                  </span>
                  <span className="text-xs text-gray-500">
                    {new Date(message.created_at).toLocaleTimeString([], {
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </span>
                </div>

                <div
                  className={`px-4 py-2 rounded-lg ${
                    isOwn
                      ? 'bg-blue-600 text-white rounded-tr-none'
                      : 'bg-gray-800 text-gray-100 rounded-tl-none'
                  }`}
                >
                  <p className="whitespace-pre-wrap break-words">{message.content}</p>
                </div>

                {message.attachments && message.attachments.length > 0 && (
                  <div className="mt-2 space-y-2">
                    {message.attachments.map((att) => (
                      <a
                        key={att.id}
                        href={att.file.file}
                        target="_blank"
                        rel="noopener noreferrer"
                        className={`flex items-center gap-2 p-2 rounded bg-gray-900/50 hover:bg-gray-900 transition-colors text-sm ${
                          isOwn ? 'text-blue-100' : 'text-gray-300'
                        }`}
                      >
                        <FileText className="w-4 h-4" />
                        <span className="truncate max-w-[200px]">
                          {att.file.name}
                        </span>
                      </a>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        );
      })}
      <div ref={messagesEndRef} />
    </div>
  );
};
