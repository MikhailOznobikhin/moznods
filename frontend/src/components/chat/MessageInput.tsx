import React, { useState } from 'react';
import { Send } from 'lucide-react';
import { useChatStore } from '../../store/useChatStore';

export const MessageInput = () => {
  const { sendMessage, isConnected } = useChatStore();
  const [content, setContent] = useState('');
  const [isSending, setIsSending] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!content.trim() || !isConnected) return;

    try {
      setIsSending(true);
      sendMessage({
        content: content.trim(),
        // attachment_ids: attachments.map(f => f.id),
      });
      setContent('');
    } catch (error) {
      console.error('Failed to send message:', error);
    } finally {
      setIsSending(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e as any);
    }
  };

  // const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => { /* disabled */ };
  // const removeAttachment = (id: number) => { /* disabled */ };

  return (
    <div className="p-4 border-t border-gray-800 bg-gray-900">
      {/* Attachments Preview disabled */}

      <form onSubmit={handleSubmit} className="flex items-end gap-2">
        {/* File upload disabled */}

        <div className="flex-1 bg-gray-800 rounded-lg overflow-hidden relative">
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={isConnected ? "Type a message..." : "Connecting..."}
            className="w-full p-3 bg-transparent text-white placeholder-gray-500 focus:outline-none resize-none max-h-32 min-h-[44px]"
            rows={1}
            disabled={!isConnected}
          />
        </div>

        <button
          type="submit"
          disabled={!content.trim() || !isConnected || isSending}
          className="p-2 bg-blue-600 text-white rounded-full hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Send className="w-5 h-5" />
        </button>
      </form>
    </div>
  );
};
