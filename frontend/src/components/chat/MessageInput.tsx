import React, { useState, useRef } from 'react';
import { Send, Paperclip, X, FileText, Loader2 } from 'lucide-react';
import { useChatStore } from '../../store/useChatStore';
import {type FileData } from '../../types/chat';

export const MessageInput = () => {
  const { sendMessage, uploadFile, isConnected } = useChatStore();
  const [content, setContent] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [attachments, setAttachments] = useState<FileData[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if ((!content.trim() && attachments.length === 0) || !isConnected) return;

    try {
      setIsSending(true);
      sendMessage({
        content: content.trim(),
        attachment_ids: attachments.map(f => f.id),
      });
      setContent('');
      setAttachments([]);
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

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files?.length) return;
    
    setIsUploading(true);
    const files = Array.from(e.target.files);
    
    try {
      for (const file of files) {
        const uploadedFile = await uploadFile(file);
        setAttachments(prev => [...prev, uploadedFile]);
      }
    } catch (error) {
      console.error('Failed to upload file:', error);
      alert('File upload failed. Please try again.');
    } finally {
      setIsUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const removeAttachment = (id: number) => {
    setAttachments(prev => prev.filter(f => f.id !== id));
  };

  return (
    <div className="p-4 border-t border-gray-800 bg-gray-900">
      {/* Attachments Preview */}
      {attachments.length > 0 && (
        <div className="flex flex-wrap gap-2 mb-2">
          {attachments.map((file) => (
            <div
              key={file.id}
              className="flex items-center gap-2 bg-gray-800 rounded px-2 py-1 text-sm text-gray-300"
            >
              <FileText className="w-3 h-3" />
              <span className="truncate max-w-[150px]">{file.name}</span>
              <button
                type="button"
                onClick={() => removeAttachment(file.id)}
                className="hover:text-white"
              >
                <X className="w-3 h-3" />
              </button>
            </div>
          ))}
        </div>
      )}

      <form onSubmit={handleSubmit} className="flex items-end gap-2">
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          className="p-2 text-gray-400 hover:text-white transition-colors disabled:opacity-50"
          disabled={!isConnected || isUploading}
        >
          {isUploading ? (
            <Loader2 className="w-5 h-5 animate-spin" />
          ) : (
            <Paperclip className="w-5 h-5" />
          )}
        </button>
        <input
          type="file"
          ref={fileInputRef}
          className="hidden"
          multiple
          onChange={handleFileSelect}
          disabled={isUploading}
        />

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
          disabled={(!content.trim() && attachments.length === 0) || !isConnected || isSending || isUploading}
          className="p-2 bg-blue-600 text-white rounded-full hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Send className="w-5 h-5" />
        </button>
      </form>
    </div>
  );
};
