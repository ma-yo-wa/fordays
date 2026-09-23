const URL_REGEX = /(https?:\/\/[^\s]+)/g;

export default function Linkify({
  text,
  className,
}: {
  text: string;
  className?: string;
}) {
  if (!text) return null;
  const parts = text.split(URL_REGEX);
  
  return (
    <span className={className}>
      {parts.map((part, i) => {
        if (part.match(URL_REGEX)) {
          return (
            <a
              key={i}
              href={part}
              target="_blank"
              rel="noopener noreferrer"
              onClick={(e) => e.stopPropagation()}
              style={{ color: 'inherit', textDecoration: 'underline' }}
            >
              {part}
            </a>
          );
        }
        return part;
      })}
    </span>
  );
}