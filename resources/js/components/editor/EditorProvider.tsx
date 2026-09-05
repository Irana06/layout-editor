import { createContext, useContext, useReducer, useRef, useState } from 'react';
import type { Dispatch, MutableRefObject, ReactNode } from 'react';
import { defaultCamera } from '@/lib/iso-grid';
import type { Camera } from '@/lib/iso-grid';
import { editorReducer, initialEditorState } from './editor-state';
import type { EditorAction, EditorState } from './editor-state';

type EditorContextValue = {
    state: EditorState;
    dispatch: Dispatch<EditorAction>;
    /** Pan/zoom stays out of the reducer — it changes per-pixel during drag, so it's an
     * imperative ref the canvas mutates directly. `zoomDisplay` is a low-frequency mirror
     * of cameraRef.current.zoom (as a 100-1000% figure relative to `baseFitRef`, the scale
     * at which the scenery exactly fits the canvas) kept for the toolbar's indicator/slider. */
    cameraRef: MutableRefObject<Camera>;
    baseFitRef: MutableRefObject<number>;
    zoomDisplay: number;
    setZoomDisplay: (zoom: number) => void;
    /** Populated by IsometricCanvas (the only thing that knows how to redraw) so the
     * toolbar's zoom slider/buttons can drive zoom without prop-drilling a draw callback. */
    zoomActionsRef: MutableRefObject<{
        setZoomPercent: (percent: number) => void;
    } | null>;
    imageCache: MutableRefObject<Map<string, HTMLImageElement>>;
};

const EditorContext = createContext<EditorContextValue | null>(null);

export function EditorProvider({
    children,
    initial,
}: {
    children: ReactNode;
    initial?: Partial<EditorState>;
}) {
    const [state, dispatch] = useReducer(
        editorReducer,
        initialEditorState(initial),
    );
    const cameraRef = useRef<Camera>(defaultCamera());
    const baseFitRef = useRef(1);
    const zoomActionsRef = useRef<{
        setZoomPercent: (percent: number) => void;
    } | null>(null);
    const imageCache = useRef(new Map<string, HTMLImageElement>());
    const [zoomDisplay, setZoomDisplay] = useState(100);

    return (
        <EditorContext.Provider
            value={{
                state,
                dispatch,
                cameraRef,
                baseFitRef,
                zoomActionsRef,
                imageCache,
                zoomDisplay,
                setZoomDisplay,
            }}
        >
            {children}
        </EditorContext.Provider>
    );
}

export function useEditor(): EditorContextValue {
    const ctx = useContext(EditorContext);

    if (!ctx) {
        throw new Error('useEditor must be used within an EditorProvider');
    }

    return ctx;
}
