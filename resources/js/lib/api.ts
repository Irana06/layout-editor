function csrfToken(): string {
    return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? '';
}

type RouteLike = { url: string; method: string };

/**
 * JSON fetch wrapper matching this app's existing CSRF-header convention.
 *
 * Wayfinder emits route methods lowercase (`'patch'`, `'post'`, …). The Fetch spec only
 * normalises a fixed list to uppercase — DELETE, GET, HEAD, OPTIONS, POST, PUT — and
 * PATCH is deliberately NOT on it, so `method: 'patch'` goes out on the wire literally
 * lowercase. nginx only accepts uppercase method tokens and rejects the request with a
 * bare 400 before it ever reaches PHP. Uppercasing here keeps every verb safe.
 */
export async function apiFetch<T>(route: RouteLike, body?: unknown): Promise<T> {
    const isFormData = body instanceof FormData;

    const response = await fetch(route.url, {
        method: route.method.toUpperCase(),
        headers: {
            Accept: 'application/json',
            'X-CSRF-TOKEN': csrfToken(),
            ...(isFormData ? {} : { 'Content-Type': 'application/json' }),
        },
        body: body === undefined ? undefined : isFormData ? body : JSON.stringify(body),
    });

    if (!response.ok) {
        const text = await response.text();

        throw new Error(text || `Request failed: ${response.status}`);
    }

    if (response.status === 204) {
        return undefined as T;
    }

    return response.json() as Promise<T>;
}
