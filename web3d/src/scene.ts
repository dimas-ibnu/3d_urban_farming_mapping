import * as THREE from 'three';

import {
  isElevated,
  isPlacementValid,
  spaceCentre,
  spaceExtent,
} from './geometry';
import {
  applyTransform,
  buildItemMesh,
  disposeObject,
  setInvalid,
  setSelected,
} from './item_meshes';
import { DEFAULT_SPACE, type PlacedItem, type Space, type Vec2, type ViewMode } from './protocol';

/** How much of the perspective camera's reach the plan view shows. */
const PLAN_VIEW_FRACTION = 0.6;

export type SceneCallbacks = {
  /** The user tapped an item, or empty space to clear the selection. */
  onSelect: (id: string | null) => void;
  /** The user finished dragging an item. A request — Dart decides. */
  onMove: (id: string, position: Vec2, mountHeightM?: number) => void;
};

/**
 * The layout editor.
 *
 * It renders whatever the app pushed at it and reports back what the user did;
 * it keeps a copy of the model only so it can hit-test, snap cameras and give
 * instant drag feedback (see `docs/APP_GOAL.md`, "Responsibilities").
 *
 * Rendering is on demand: every mutation and every camera move calls
 * `invalidate()`, and `renderIfNeeded()` is a no-op otherwise. A static plan
 * therefore costs nothing per frame, which is the battery fix asked for in
 * `docs/PERF_NOTES.md`.
 */
export class Scene {
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly perspective: THREE.PerspectiveCamera;
  private readonly orthographic: THREE.OrthographicCamera;
  private readonly raycaster = new THREE.Raycaster();

  private readonly spaceGroup = new THREE.Group();
  private readonly itemGroup = new THREE.Group();
  private readonly meshes = new Map<string, THREE.Object3D>();
  private readonly items = new Map<string, PlacedItem>();
  private readonly invalidIds = new Set<string>();

  private space: Space = DEFAULT_SPACE;
  private view: ViewMode = '3d';
  private selectedId: string | null = null;
  private needsRender = true;

  /** Camera orbit, in radians / metres, around `target`. */
  private azimuth = Math.PI * 0.25;
  private polar = Math.PI * 0.32;
  private distance = 5;
  private target = new THREE.Vector3(0, 0.3, 0);

  constructor(
    private readonly canvas: HTMLCanvasElement,
    private readonly callbacks: SceneCallbacks,
  ) {
    this.renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: false, // Cheaper on low-end Android WebViews; we cap the DPR instead.
      powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    this.scene.background = new THREE.Color(0xdfeae0);
    this.perspective = new THREE.PerspectiveCamera(50, 1, 0.1, 100);
    this.orthographic = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 100);

    const sun = new THREE.DirectionalLight(0xfff4e0, 2.2);
    sun.position.set(4, 7, 3);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);
    sun.shadow.camera.left = -6;
    sun.shadow.camera.right = 6;
    sun.shadow.camera.top = 6;
    sun.shadow.camera.bottom = -6;
    this.scene.add(sun);
    this.scene.add(new THREE.HemisphereLight(0xbfd9ff, 0x4a5a3a, 1.0));

    this.scene.add(this.spaceGroup);
    this.scene.add(this.itemGroup);
    this.rebuildSpace();

    this.bindPointer();
    window.addEventListener('resize', () => this.resize());
    this.resize();
  }

  // --- commands from the app -------------------------------------------------

  setSpace(space: Space): void {
    this.space = space.footprint.length >= 3 ? space : DEFAULT_SPACE;
    this.rebuildSpace();
    this.frameCamera();
    this.revalidateAll();
    this.invalidate();
  }

  upsertItem(item: PlacedItem): void {
    const existing = this.meshes.get(item.id);
    const previous = this.items.get(item.id);
    this.items.set(item.id, item);

    // A drag only ever changes the transform, so reuse the mesh unless the
    // item's shape actually changed — rebuilding on every frame of a drag
    // would allocate a dozen geometries a second.
    if (existing && previous && sameShape(previous, item)) {
      applyTransform(existing, item);
    } else {
      if (existing) this.disposeMesh(item.id);
      const mesh = buildItemMesh(item);
      this.itemGroup.add(mesh);
      this.meshes.set(item.id, mesh);
      setSelected(mesh, this.selectedId === item.id);
    }
    this.revalidateAll();
    this.invalidate();
  }

  removeItem(id: string): void {
    if (!this.meshes.has(id)) return;
    this.disposeMesh(id);
    this.items.delete(id);
    this.invalidIds.delete(id);
    if (this.selectedId === id) this.selectedId = null;
    this.revalidateAll();
    this.invalidate();
  }

  clearItems(): void {
    for (const id of [...this.meshes.keys()]) this.disposeMesh(id);
    this.items.clear();
    this.invalidIds.clear();
    this.selectedId = null;
    this.invalidate();
  }

  setView(mode: ViewMode): void {
    if (this.view === mode) return;
    this.view = mode;
    this.resize();
    this.invalidate();
  }

  setSelection(id: string | null): void {
    if (this.selectedId === id) return;
    const previous = this.selectedId === null ? null : this.meshes.get(this.selectedId);
    if (previous) setSelected(previous, false);
    this.selectedId = id;
    const next = id === null ? null : this.meshes.get(id);
    if (next) setSelected(next, true);
    this.invalidate();
  }

  /** The app's authoritative verdict, which overrides the local guess. */
  setInvalidItems(ids: string[]): void {
    this.invalidIds.clear();
    for (const id of ids) this.invalidIds.add(id);
    this.applyInvalidTints();
    this.invalidate();
  }

  // --- rendering -------------------------------------------------------------

  /** Marks the frame as stale; the next `renderIfNeeded` will draw it. */
  invalidate(): void {
    this.needsRender = true;
  }

  /** Draws only when something changed. Returns whether it drew. */
  renderIfNeeded(): boolean {
    if (!this.needsRender) return false;
    this.needsRender = false;
    this.render();
    return true;
  }

  /** Draws unconditionally — the debug FPS mode's continuous loop. */
  render(): void {
    this.updateCamera();
    this.renderer.render(this.scene, this.camera);
  }

  /** Reported in the `ready` message so we can tell software rendering apart. */
  rendererInfo(): string {
    const gl = this.renderer.getContext();
    const debug = gl.getExtension('WEBGL_debug_renderer_info');
    const raw = debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : null;
    return typeof raw === 'string' ? raw : 'unknown';
  }

  private get camera(): THREE.Camera {
    return this.view === '2d' ? this.orthographic : this.perspective;
  }

  private updateCamera(): void {
    if (this.view === '2d') {
      this.orthographic.position.set(this.target.x, 20, this.target.z);
      // Straight down. `up` points along -z so north stays at the top of the
      // plan, which is what the compass dial in the app promises.
      this.orthographic.up.set(0, 0, -1);
      this.orthographic.lookAt(this.target.x, 0, this.target.z);
      return;
    }
    this.perspective.position.set(
      this.target.x + this.distance * Math.sin(this.polar) * Math.sin(this.azimuth),
      this.target.y + this.distance * Math.cos(this.polar),
      this.target.z + this.distance * Math.sin(this.polar) * Math.cos(this.azimuth),
    );
    this.perspective.lookAt(this.target);
  }

  private resize(): void {
    const width = this.canvas.clientWidth || window.innerWidth;
    const height = this.canvas.clientHeight || window.innerHeight;
    this.renderer.setSize(width, height, false);

    this.perspective.aspect = width / Math.max(height, 1);
    this.perspective.updateProjectionMatrix();

    // Both cameras are driven by the same `distance`, so the wheel zooms the
    // plan and the orbit alike. The plan wants a tighter frame than the
    // perspective camera, which has to stand back far enough for the walls —
    // hence the fraction.
    const aspect = width / Math.max(height, 1);
    const halfHeight = (this.distance * PLAN_VIEW_FRACTION) / 2;
    const halfWidth = halfHeight * aspect;
    this.orthographic.left = -halfWidth;
    this.orthographic.right = halfWidth;
    this.orthographic.top = halfHeight;
    this.orthographic.bottom = -halfHeight;
    this.orthographic.updateProjectionMatrix();

    this.invalidate();
  }

  // --- space geometry --------------------------------------------------------

  private rebuildSpace(): void {
    for (const child of [...this.spaceGroup.children]) {
      this.spaceGroup.remove(child);
      disposeObject(child);
    }

    // `ExtrudeGeometry` builds in the XY plane and grows along +z. Feeding it
    // (x, -z) and tipping it back by a quarter turn puts the shape's y on the
    // world z with the extrusion pointing up, so the slab's front faces end up
    // facing the sky instead of the ground.
    const shape = new THREE.Shape(
      this.space.footprint.map((point) => new THREE.Vector2(point.x, -point.z)),
    );
    const thickness = 0.08;
    const slab = new THREE.Mesh(
      new THREE.ExtrudeGeometry(shape, { depth: thickness, bevelEnabled: false }),
      new THREE.MeshStandardMaterial({ color: 0xcfc3ad, roughness: 1 }),
    );
    slab.rotation.x = -Math.PI / 2;
    slab.position.y = -thickness;
    slab.receiveShadow = true;
    slab.name = 'floor';
    this.spaceGroup.add(slab);

    this.spaceGroup.add(this.buildGrid());

    for (const barrier of this.space.barriers) {
      const length = Math.hypot(
        barrier.end.x - barrier.start.x,
        barrier.end.z - barrier.start.z,
      );
      if (length === 0) continue;
      const solid = barrier.kind !== 'railing';
      const slabMesh = new THREE.Mesh(
        new THREE.BoxGeometry(length, barrier.heightM, 0.06),
        new THREE.MeshStandardMaterial({
          color: barrier.kind === 'obstacle' ? 0x9a9a92 : 0xe4e0d6,
          roughness: 0.95,
          transparent: !solid,
          opacity: solid ? 1 : 0.35,
        }),
      );
      slabMesh.position.set(
        (barrier.start.x + barrier.end.x) / 2,
        barrier.heightM / 2,
        (barrier.start.z + barrier.end.z) / 2,
      );
      // The box's length runs along its local +x, and a turn of `θ` about +y
      // sends that axis to (cos θ, 0, −sin θ) — so the angle is measured from
      // +x towards −z, not the other way round.
      slabMesh.rotation.y = Math.atan2(
        -(barrier.end.z - barrier.start.z),
        barrier.end.x - barrier.start.x,
      );
      slabMesh.castShadow = solid;
      slabMesh.receiveShadow = true;
      this.spaceGroup.add(slabMesh);
    }
  }

  /** A half-metre grid, the measuring aid for the 2D plan view. */
  private buildGrid(): THREE.Object3D {
    const extent = Math.ceil(spaceExtent(this.space)) + 1;
    const centre = spaceCentre(this.space);
    const grid = new THREE.GridHelper(extent * 2, extent * 4, 0x9fb4a0, 0xc4d2c4);
    grid.position.set(centre.x, 0.005, centre.z);
    const material = grid.material as THREE.Material;
    material.transparent = true;
    material.opacity = 0.5;
    return grid;
  }

  private frameCamera(): void {
    const centre = spaceCentre(this.space);
    // Aim a third of the way up the room and stand back far enough for the
    // taller of the two dimensions: a narrow balcony with a 2.6 m wall needs
    // more room than its floor alone suggests.
    const extent = Math.max(spaceExtent(this.space), this.space.heightM);
    this.target.set(centre.x, this.space.heightM * 0.35, centre.z);
    this.distance = Math.max(extent * 2.2, 3);
    this.resize();
  }

  // --- validity --------------------------------------------------------------

  /**
   * Re-runs the local check for every item.
   *
   * Only a guess for instant feedback: Dart re-checks the same rules and sends
   * `setInvalidItems`, which wins. With at most a few dozen items the O(n²)
   * pass is far cheaper than a frame.
   */
  private revalidateAll(): void {
    const all = [...this.items.values()];
    this.invalidIds.clear();
    for (const item of all) {
      if (!isPlacementValid(this.space, item, all)) this.invalidIds.add(item.id);
    }
    this.applyInvalidTints();
  }

  private applyInvalidTints(): void {
    for (const [id, mesh] of this.meshes) setInvalid(mesh, this.invalidIds.has(id));
  }

  private disposeMesh(id: string): void {
    const mesh = this.meshes.get(id);
    if (!mesh) return;
    this.itemGroup.remove(mesh);
    disposeObject(mesh);
    this.meshes.delete(id);
  }

  // --- interaction -----------------------------------------------------------

  private bindPointer(): void {
    let gesture: 'none' | 'camera' | 'item' = 'none';
    let moved = 0;
    let lastX = 0;
    let lastY = 0;
    let dragId: string | null = null;
    let dragOffset: Vec2 = { x: 0, z: 0 };

    this.canvas.addEventListener('pointerdown', (event) => {
      moved = 0;
      lastX = event.clientX;
      lastY = event.clientY;
      this.canvas.setPointerCapture(event.pointerId);

      const hit = this.pickItem(event);
      if (hit === null) {
        gesture = 'camera';
        return;
      }
      const item = this.items.get(hit);
      if (!item) {
        gesture = 'camera';
        return;
      }
      gesture = 'item';
      dragId = hit;
      const ground = this.pointerOnPlane(event, item.mountHeightM);
      dragOffset = ground
        ? { x: item.position.x - ground.x, z: item.position.z - ground.z }
        : { x: 0, z: 0 };
    });

    this.canvas.addEventListener('pointermove', (event) => {
      if (gesture === 'none') return;
      const dx = event.clientX - lastX;
      const dy = event.clientY - lastY;
      lastX = event.clientX;
      lastY = event.clientY;
      moved += Math.abs(dx) + Math.abs(dy);

      if (gesture === 'item') {
        if (dragId !== null) this.dragItem(dragId, event, dragOffset);
        return;
      }
      if (this.view === '2d') {
        // Panning the plan: a pixel of drag is a pixel of plan, whatever the
        // zoom, so the floor follows the finger exactly.
        const metresPerPixel =
          (this.distance * PLAN_VIEW_FRACTION) /
          Math.max(this.canvas.clientHeight, 1);
        this.target.x -= dx * metresPerPixel;
        this.target.z -= dy * metresPerPixel;
      } else {
        this.azimuth -= dx * 0.008;
        this.polar = THREE.MathUtils.clamp(this.polar - dy * 0.006, 0.12, Math.PI / 2 - 0.05);
      }
      this.invalidate();
    });

    const end = (event: PointerEvent) => {
      if (gesture === 'none') return;
      const wasDragging = gesture === 'item';
      const id = dragId;
      gesture = 'none';
      dragId = null;
      this.canvas.releasePointerCapture(event.pointerId);

      if (wasDragging && id !== null) {
        if (moved < 8) {
          this.reportSelection(id);
          return;
        }
        const item = this.items.get(id);
        if (item) {
          this.callbacks.onMove(
            id,
            item.position,
            isElevated(item) ? item.mountHeightM : undefined,
          );
        }
        return;
      }
      if (moved < 8) this.reportSelection(null);
    };
    this.canvas.addEventListener('pointerup', end);
    this.canvas.addEventListener('pointercancel', end);

    this.canvas.addEventListener(
      'wheel',
      (event) => {
        event.preventDefault();
        this.distance = THREE.MathUtils.clamp(
          this.distance * (1 + Math.sign(event.deltaY) * 0.12),
          0.8,
          40,
        );
        this.resize();
      },
      { passive: false },
    );
  }

  /** Moves the dragged item locally and tints it; Dart gets the result on drop. */
  private dragItem(id: string, event: PointerEvent, offset: Vec2): void {
    const item = this.items.get(id);
    const mesh = this.meshes.get(id);
    if (!item || !mesh) return;
    const ground = this.pointerOnPlane(event, item.mountHeightM);
    if (!ground) return;

    const moved: PlacedItem = {
      ...item,
      position: { x: ground.x + offset.x, z: ground.z + offset.z },
    };
    this.items.set(id, moved);
    applyTransform(mesh, moved);

    const valid = isPlacementValid(this.space, moved, this.items.values());
    if (valid) this.invalidIds.delete(id);
    else this.invalidIds.add(id);
    setInvalid(mesh, !valid);
    this.invalidate();
  }

  private reportSelection(id: string | null): void {
    if (id === this.selectedId) return;
    this.setSelection(id);
    this.callbacks.onSelect(id);
  }

  private pointerCoordinates(event: PointerEvent): THREE.Vector2 {
    const rect = this.canvas.getBoundingClientRect();
    return new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
  }

  /** Where the pointer ray crosses the horizontal plane at height `y`. */
  private pointerOnPlane(event: PointerEvent, y: number): Vec2 | null {
    this.raycaster.setFromCamera(this.pointerCoordinates(event), this.camera);
    const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -y);
    const point = new THREE.Vector3();
    if (!this.raycaster.ray.intersectPlane(plane, point)) return null;
    return { x: point.x, z: point.z };
  }

  private pickItem(event: PointerEvent): string | null {
    this.raycaster.setFromCamera(this.pointerCoordinates(event), this.camera);
    const hit = this.raycaster.intersectObjects(this.itemGroup.children, true)[0];
    for (let object: THREE.Object3D | null = hit?.object ?? null; object; object = object.parent) {
      const candidate = object.userData['id'];
      if (typeof candidate === 'string') return candidate;
    }
    return null;
  }
}

/** Whether two revisions of an item can share a mesh. */
function sameShape(a: PlacedItem, b: PlacedItem): boolean {
  return (
    a.type === b.type &&
    a.levels === b.levels &&
    a.size.widthM === b.size.widthM &&
    a.size.depthM === b.size.depthM &&
    a.size.heightM === b.size.heightM
  );
}
