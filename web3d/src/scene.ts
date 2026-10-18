import * as THREE from 'three';

export type PotSpec = {
  id: string;
  x: number;
  z: number;
  radius: number;
  height: number;
  color?: string;
};

/**
 * The prototype scene: a box-shaped balcony floor plus pots.
 *
 * It holds no persistent state — Flutter owns the project and replays it here
 * through the bridge (see `docs/APP_GOAL.md`, "Responsibilities").
 */
export class Scene {
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera: THREE.PerspectiveCamera;
  private readonly raycaster = new THREE.Raycaster();
  private readonly pots = new Map<string, THREE.Mesh>();
  private readonly potGroup = new THREE.Group();

  private floor: THREE.Mesh;
  private selectedId: string | null = null;

  /** Camera orbit, in radians / metres. */
  private azimuth = Math.PI * 0.25;
  private polar = Math.PI * 0.32;
  private distance = 6;

  constructor(
    private readonly canvas: HTMLCanvasElement,
    private readonly onSelect: (id: string | null) => void,
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
    this.camera = new THREE.PerspectiveCamera(50, 1, 0.1, 100);

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

    this.floor = this.buildFloor(2, 1.2);
    this.scene.add(this.floor);
    this.scene.add(this.potGroup);

    this.bindPointer();
    window.addEventListener('resize', () => this.resize());
    this.resize();
  }

  setFloor(width: number, depth: number): void {
    this.scene.remove(this.floor);
    this.floor.geometry.dispose();
    this.floor = this.buildFloor(width, depth);
    this.scene.add(this.floor);
    this.distance = Math.max(width, depth) * 2.6;
  }

  addPot(spec: PotSpec): void {
    this.removePot(spec.id);
    const geometry = new THREE.CylinderGeometry(spec.radius, spec.radius * 0.78, spec.height, 20);
    const material = new THREE.MeshStandardMaterial({
      color: new THREE.Color(spec.color ?? '#b4603a'),
      roughness: 0.85,
    });
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(spec.x, spec.height / 2, spec.z);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    mesh.userData['id'] = spec.id;

    // A stand-in for the crop, so a pot reads as "planted" in the prototype.
    const foliage = new THREE.Mesh(
      new THREE.SphereGeometry(spec.radius * 1.15, 16, 12),
      new THREE.MeshStandardMaterial({ color: 0x4e8c3a, roughness: 0.9, flatShading: true }),
    );
    foliage.position.y = spec.height * 0.78;
    foliage.scale.y = 0.8;
    foliage.castShadow = true;
    mesh.add(foliage);

    this.potGroup.add(mesh);
    this.pots.set(spec.id, mesh);
  }

  removePot(id: string): void {
    const mesh = this.pots.get(id);
    if (!mesh) return;
    this.potGroup.remove(mesh);
    mesh.geometry.dispose();
    this.pots.delete(id);
    if (this.selectedId === id) this.selectedId = null;
  }

  clearPots(): void {
    for (const id of [...this.pots.keys()]) this.removePot(id);
  }

  render(): void {
    const target = new THREE.Vector3(0, 0.3, 0);
    this.camera.position.set(
      target.x + this.distance * Math.sin(this.polar) * Math.sin(this.azimuth),
      target.y + this.distance * Math.cos(this.polar),
      target.z + this.distance * Math.sin(this.polar) * Math.cos(this.azimuth),
    );
    this.camera.lookAt(target);
    this.renderer.render(this.scene, this.camera);
  }

  /** Reported in the `ready` message so we can tell software rendering apart. */
  rendererInfo(): string {
    const gl = this.renderer.getContext();
    const debug = gl.getExtension('WEBGL_debug_renderer_info');
    const raw = debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : null;
    return typeof raw === 'string' ? raw : 'unknown';
  }

  private buildFloor(width: number, depth: number): THREE.Mesh {
    const slab = new THREE.Mesh(
      new THREE.BoxGeometry(width, 0.08, depth),
      new THREE.MeshStandardMaterial({ color: 0xcfc3ad, roughness: 1 }),
    );
    slab.position.y = -0.04;
    slab.receiveShadow = true;
    return slab;
  }

  private resize(): void {
    const width = this.canvas.clientWidth || window.innerWidth;
    const height = this.canvas.clientHeight || window.innerHeight;
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / Math.max(height, 1);
    this.camera.updateProjectionMatrix();
  }

  /** Drag orbits the camera; a tap that did not drag picks a pot. */
  private bindPointer(): void {
    let dragging = false;
    let moved = 0;
    let lastX = 0;
    let lastY = 0;

    this.canvas.addEventListener('pointerdown', (event) => {
      dragging = true;
      moved = 0;
      lastX = event.clientX;
      lastY = event.clientY;
      this.canvas.setPointerCapture(event.pointerId);
    });

    this.canvas.addEventListener('pointermove', (event) => {
      if (!dragging) return;
      const dx = event.clientX - lastX;
      const dy = event.clientY - lastY;
      lastX = event.clientX;
      lastY = event.clientY;
      moved += Math.abs(dx) + Math.abs(dy);
      this.azimuth -= dx * 0.008;
      this.polar = THREE.MathUtils.clamp(this.polar - dy * 0.006, 0.12, Math.PI / 2 - 0.05);
    });

    const end = (event: PointerEvent) => {
      if (!dragging) return;
      dragging = false;
      this.canvas.releasePointerCapture(event.pointerId);
      if (moved < 8) this.pick(event);
    };
    this.canvas.addEventListener('pointerup', end);
    this.canvas.addEventListener('pointercancel', end);
  }

  private pick(event: PointerEvent): void {
    const rect = this.canvas.getBoundingClientRect();
    const pointer = new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
    this.raycaster.setFromCamera(pointer, this.camera);
    const hit = this.raycaster.intersectObjects(this.potGroup.children, true)[0];

    let id: string | null = null;
    for (let object: THREE.Object3D | null = hit?.object ?? null; object; object = object.parent) {
      const candidate = object.userData['id'];
      if (typeof candidate === 'string') {
        id = candidate;
        break;
      }
    }

    if (id === this.selectedId) return;
    this.selectedId = id;
    this.onSelect(id);
  }
}
