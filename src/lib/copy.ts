import rawCopy from '../../shared/copy.json';

export const Copy = rawCopy;

export function formatCopy(template: string, vars: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (_, key) => String(vars[key] ?? `{${key}}`));
}
