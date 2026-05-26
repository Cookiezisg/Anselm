// Spinner — CSS-rotated ring. The `.spinner` rule already exists in the
// boilerplate (keyframes spin + 1.5px border). Use size 12 or 16.

type SpinnerProps = {
  size?: number;
  color?: string;
  className?: string;
};

export function Spinner({ size = 12, color = "currentColor", className = "" }: SpinnerProps) {
  const style = { width: size, height: size, borderTopColor: color };
  return <span className={`spinner ${className}`} style={style} />;
}
