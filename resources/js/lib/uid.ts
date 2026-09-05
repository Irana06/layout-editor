/**
 * Client-side unique id for placed buildings (React keys + selection tracking only —
 * never persisted; the server stores building_type_id/level/gx/gy).
 *
 * `crypto.randomUUID()` only exists in secure contexts, so it is unavailable when the app
 * is served over plain HTTP on a non-localhost host — e.g. a local `*.test` domain. Fall
 * back to `getRandomValues`, then to `Math.random`, so placement keeps working there.
 */
export function uid(): string {
    if (
        typeof crypto !== 'undefined' &&
        typeof crypto.randomUUID === 'function'
    ) {
        return crypto.randomUUID();
    }

    if (
        typeof crypto !== 'undefined' &&
        typeof crypto.getRandomValues === 'function'
    ) {
        const bytes = crypto.getRandomValues(new Uint8Array(16));

        return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join(
            '',
        );
    }

    return `${Date.now().toString(16)}-${Math.random().toString(16).slice(2)}`;
}
