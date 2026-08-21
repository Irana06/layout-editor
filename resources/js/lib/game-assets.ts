/** All building/scenery images are served as static files from public/game/... (see the
 * `import:legacy-assets` command and app/Support/GameAssetUploader.php, which write there). */
export function gameAssetUrl(path: string): string {
    return `/game/${path}`;
}
