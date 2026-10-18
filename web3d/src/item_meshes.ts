import * as THREE from 'three';

import type { PlacedItem } from './protocol';

/**
 * Builds the mesh for one placed item.
 *
 * Every item is a `THREE.Group` tagged with its id, so a raycast hit anywhere
 * inside it resolves back to the item. The group's origin is the centre of the
 * item's footprint at floor level, which is exactly what `PlacedItem.position`
 * and `mountHeightM` describe — so positioning is a straight copy, with no
 * per-type offsets to keep in sync with Dart.
 */

const SOIL = 0x5a4632;
const FOLIAGE = 0x4e8c3a;
const TERRACOTTA = 0xb4603a;
const TIMBER = 0x8a6b4a;
const PLASTIC = 0xcfd8c5;

export type ItemMesh = THREE.Group & { userData: { id: string } };

export function buildItemMesh(item: PlacedItem): ItemMesh {
  const group = new THREE.Group() as ItemMesh;
  group.userData.id = item.id;

  switch (item.type) {
    case 'pot':
      buildPot(group, item);
      break;
    case 'verticalRack':
      buildRack(group, item);
      break;
    case 'hangingPlanter':
      buildHangingPlanter(group, item);
      break;
    case 'wallPlanter':
      buildWallPlanter(group, item);
      break;
  }

  applyTransform(group, item);
  return group;
}

/** Moves an existing mesh instead of rebuilding it — the drag path. */
export function applyTransform(group: THREE.Object3D, item: PlacedItem): void {
  group.position.set(item.position.x, item.mountHeightM, item.position.z);
  group.rotation.y = (item.rotationDeg * Math.PI) / 180;
}

/**
 * Tints an item red while it sits somewhere it may not.
 *
 * Materials are cloned per item, so an emissive on one never leaks into
 * another; the cost is a handful of extra materials in a scene that holds a
 * few dozen objects at most.
 */
export function setInvalid(group: THREE.Object3D, invalid: boolean): void {
  group.traverse((child) => {
    if (!(child instanceof THREE.Mesh)) return;
    const material = child.material;
    if (!(material instanceof THREE.MeshStandardMaterial)) return;
    material.emissive.setHex(invalid ? 0x8b1a1a : 0x000000);
    material.emissiveIntensity = invalid ? 0.7 : 0;
  });
}

/** A ring on the floor under the selected item. */
export function setSelected(group: THREE.Object3D, selected: boolean): void {
  const halo = group.getObjectByName('halo');
  if (halo) halo.visible = selected;
}

/** Frees the GPU buffers of anything with a geometry — meshes and helpers alike. */
export function disposeObject(root: THREE.Object3D): void {
  root.traverse((child) => {
    const holder = child as Partial<THREE.Mesh>;
    holder.geometry?.dispose();
    const material = holder.material;
    if (Array.isArray(material)) material.forEach((entry) => entry.dispose());
    else material?.dispose();
  });
}

function standard(color: number, roughness = 0.85): THREE.MeshStandardMaterial {
  return new THREE.MeshStandardMaterial({ color, roughness });
}

function mesh(geometry: THREE.BufferGeometry, material: THREE.Material): THREE.Mesh {
  const result = new THREE.Mesh(geometry, material);
  result.castShadow = true;
  result.receiveShadow = true;
  return result;
}

function addHalo(group: THREE.Group, radius: number): void {
  const halo = new THREE.Mesh(
    new THREE.RingGeometry(radius, radius * 1.18, 32),
    new THREE.MeshBasicMaterial({
      color: 0xffc83d,
      transparent: true,
      opacity: 0.9,
      side: THREE.DoubleSide,
      depthWrite: false,
    }),
  );
  halo.name = 'halo';
  halo.rotation.x = -Math.PI / 2;
  halo.position.y = 0.012;
  halo.visible = false;
  group.add(halo);
}

function foliage(radius: number, height: number): THREE.Mesh {
  const crown = mesh(
    new THREE.SphereGeometry(radius, 14, 10),
    new THREE.MeshStandardMaterial({ color: FOLIAGE, roughness: 0.9, flatShading: true }),
  );
  crown.scale.y = 0.72;
  crown.position.y = height;
  crown.receiveShadow = false;
  return crown;
}

function buildPot(group: THREE.Group, item: PlacedItem): void {
  const radius = Math.min(item.size.widthM, item.size.depthM) / 2;
  const body = mesh(
    new THREE.CylinderGeometry(radius, radius * 0.78, item.size.heightM, 20),
    standard(TERRACOTTA),
  );
  body.position.y = item.size.heightM / 2;
  group.add(body);
  group.add(foliage(radius * 1.1, item.size.heightM * 1.1));
  addHalo(group, radius * 1.25);
}

function buildRack(group: THREE.Group, item: PlacedItem): void {
  const { widthM, depthM, heightM } = item.size;
  const levels = Math.max(1, item.levels);
  const postRadius = 0.022;
  const frame = standard(TIMBER, 0.8);

  for (const [dx, dz] of [
    [-1, -1],
    [1, -1],
    [1, 1],
    [-1, 1],
  ] as const) {
    const post = mesh(new THREE.CylinderGeometry(postRadius, postRadius, heightM, 8), frame);
    post.position.set(
      (dx * (widthM / 2 - postRadius)),
      heightM / 2,
      (dz * (depthM / 2 - postRadius)),
    );
    group.add(post);
  }

  // Shelves are evenly spaced, the lowest one just off the floor: that spacing
  // is what `levels` means for the growing-area sum.
  const shelfThickness = 0.025;
  for (let level = 0; level < levels; level++) {
    const y = ((level + 1) / levels) * (heightM - shelfThickness);
    const shelf = mesh(new THREE.BoxGeometry(widthM, shelfThickness, depthM), frame);
    shelf.position.y = y;
    group.add(shelf);

    const crownRadius = Math.min(widthM, depthM) * 0.28;
    for (const offset of [-widthM * 0.25, widthM * 0.25]) {
      const crown = foliage(crownRadius, y + crownRadius * 0.7);
      crown.position.x = offset;
      group.add(crown);
    }
  }

  addHalo(group, Math.max(widthM, depthM) * 0.62);
}

function buildHangingPlanter(group: THREE.Group, item: PlacedItem): void {
  const { widthM, depthM, heightM } = item.size;
  const radius = Math.min(widthM, depthM) / 2;
  const bowl = mesh(
    new THREE.CylinderGeometry(radius, radius * 0.6, heightM, 18),
    standard(PLASTIC),
  );
  bowl.position.y = heightM / 2;
  group.add(bowl);
  group.add(foliage(radius * 1.15, heightM * 0.95));

  // A cord running up out of frame, so it reads as hanging rather than floating.
  const cord = new THREE.Mesh(
    new THREE.CylinderGeometry(0.006, 0.006, 0.6, 6),
    new THREE.MeshStandardMaterial({ color: 0x6b6b5e, roughness: 1 }),
  );
  cord.position.y = heightM + 0.3;
  group.add(cord);

  addHalo(group, radius * 1.3);
}

function buildWallPlanter(group: THREE.Group, item: PlacedItem): void {
  const { widthM, depthM, heightM } = item.size;
  const trough = mesh(new THREE.BoxGeometry(widthM, heightM, depthM), standard(SOIL, 0.95));
  trough.position.y = heightM / 2;
  group.add(trough);

  const crownRadius = Math.min(heightM, depthM) * 0.8;
  const count = Math.max(1, Math.round(widthM / 0.25));
  for (let i = 0; i < count; i++) {
    const crown = foliage(crownRadius, heightM + crownRadius * 0.4);
    crown.position.x = widthM * ((i + 0.5) / count - 0.5);
    group.add(crown);
  }

  addHalo(group, Math.max(widthM, depthM) * 0.62);
}
