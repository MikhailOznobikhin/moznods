import { useEffect, useRef } from 'react';
import { type Message } from '../../types/chat';
import { FileText, Check, CheckCheck } from 'lucide-react';
import { Avatar } from '../ui/Avatar';

interface MessageItemProps {
  message: Message;
  isOwn: boolean;
  isReadByOthers: boolean;
  onVisible: (messageId: number) => void;
}

const linkify = (text: string) => {
  const urlRegex = /(https?:\/\/[^\s]+)/g;
  return text.split(urlRegex).map((part, i) => {
    if (part.match(urlRegex)) {
      return (
        <a key={i} href={part} target="_blank" rel="noopener noreferrer" className="underline text-blue-200 hover:text-white break-all">
          {part}
        </a>
      );
    }
    return part;
  });
};

export const MessageItem = ({ message, isOwn, isReadByOthers, onVisible }: MessageItemProps) => {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          onVisible(message.id);
          // No need to disconnect, as we want to catch it just once
          // and the parent component will handle not sending duplicates.
        }
      },
      { threshold: 0.8 } // Mark as read when 80% of the message is visible
    );

    if (ref.current) {
      observer.observe(ref.current);
    }

    return () => {
      if (ref.current) {
        observer.unobserve(ref.current);
      }
    };
  }, [message.id, onVisible]);

  return (
    <div
      ref={ref}
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
            className={`px-4 py-2 rounded-lg relative ${
              isOwn
                ? 'bg-blue-600 text-white rounded-tr-none'
                : 'bg-gray-800 text-gray-100 rounded-tl-none'
            }`}
          >
            <p className="whitespace-pre-wrap break-words">{linkify(message.content)}</p>
            
            {isOwn && (
              <div className="absolute bottom-1 right-1 flex items-center">
                {isReadByOthers ? (
                  <CheckCheck className="w-3 h-3 text-blue-200" />
                ) : (
                  <Check className="w-3 h-3 text-blue-300/70" />
                )}
              </div>
            )}
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
};