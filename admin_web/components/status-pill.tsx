export function StatusPill({ status }: { status: unknown }) {
  const value = String(status ?? 'unknown');
  const tone =
    ['completed', 'success', 'approved', 'scored', 'active'].includes(value)
      ? 'success'
      : ['failed', 'rejected', 'error'].includes(value)
        ? 'danger'
        : 'warning';
  return <span className={`status ${tone}`}>{value}</span>;
}
