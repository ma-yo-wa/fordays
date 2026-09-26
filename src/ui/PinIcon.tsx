/* The location mark, drawn like every other icon: 1.7 on a 24 grid, round
   ends. Sized to the surrounding text so it replaces the emoji in place. */
export function PinIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      width="1.2em"
      height="1.2em"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      aria-hidden
    >
      <path d="M12 21c-3.5-3.5-6.5-7.4-6.5-11a6.5 6.5 0 0 1 13 0c0 3.6-3 7.5-6.5 11Z" />
      <circle cx="12" cy="10" r="2.4" />
    </svg>
  );
}
