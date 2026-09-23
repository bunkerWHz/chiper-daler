// Regenerate DarklightRig2.tscn from the canonical DarklightRig.tscn.
//
// DarklightRig2 is derived data: the canonical rig plus one documented change —
// its SoupIK solvers are replaced by native SkeletonModification2D nodes. It is
// generated rather than hand-maintained because the canonical rig keeps moving
// (clips were already added and renamed once while the copy existed), and a
// stale copy silently animates different clips than the rig it is compared to.
//
// Never hand-edit DarklightRig2.tscn: run this script instead.
//
// Usage: node tests/regenerate_darklight_rig2.mjs [--check]
import { readFileSync, writeFileSync } from "node:fs";

const SOURCE = "game/player/darklight/DarklightRig.tscn";
const TARGET = "game/player/darklight/DarklightRig2.tscn";
const CHECK_ONLY = process.argv.includes("--check");

const FK_NODES = ["FrontArmFK", "BackArmFK"];

// Native replacements for the nine SoupIK solvers, in the order the SoupIK nodes
// executed. Bone paths resolve from Skeleton2D; targets are the unchanged
// Anim Targets nodes. Bone indices are serialized explicitly because a scene
// load resolves them before the skeleton is ready (godot#73247, godot#76850),
// and flip_bend_direction is inverted relative to the SoupIK export of the same
// name: the arms need true and the legs false to reproduce the SoupIK bends.
const MODIFICATIONS = `[sub_resource type="SkeletonModification2DLookAt" id="SkeletonModification2DLookAt_head"]
bone2d_node = NodePath("Hip/Torso/Head")
bone_index = 14
target_nodepath = NodePath("../Anim Targets/Head_AT")

[sub_resource type="SkeletonModification2DTwoBoneIK" id="SkeletonModification2DTwoBoneIK_front_arm"]
joint_one_bone2d_node = NodePath("Hip/FrontArmTop")
joint_one_bone_idx = 7
joint_two_bone2d_node = NodePath("Hip/FrontArmTop/FrontArmMid")
joint_two_bone_idx = 8
target_nodepath = NodePath("../Anim Targets/FrontArmIK")
flip_bend_direction = true

[sub_resource type="SkeletonModification2DTwoBoneIK" id="SkeletonModification2DTwoBoneIK_back_arm"]
joint_one_bone2d_node = NodePath("Hip/BackArmTop")
joint_one_bone_idx = 10
joint_two_bone2d_node = NodePath("Hip/BackArmTop/BackArmMid")
joint_two_bone_idx = 11
target_nodepath = NodePath("../Anim Targets/BackArmIK")
flip_bend_direction = true

[sub_resource type="SkeletonModification2DLookAt" id="SkeletonModification2DLookAt_front_wrist"]
bone2d_node = NodePath("Hip/FrontArmTop/FrontArmMid/FrontArmBot")
bone_index = 9
target_nodepath = NodePath("../Anim Targets/FrontArmIK/FrontArm_AT")

[sub_resource type="SkeletonModification2DLookAt" id="SkeletonModification2DLookAt_back_wrist"]
bone2d_node = NodePath("Hip/BackArmTop/BackArmMid/BackArmBot")
bone_index = 12
target_nodepath = NodePath("../Anim Targets/BackArmIK/BackArm_AT")

[sub_resource type="SkeletonModification2DTwoBoneIK" id="SkeletonModification2DTwoBoneIK_front_leg"]
joint_one_bone2d_node = NodePath("Hip/FrontLegTop")
joint_one_bone_idx = 4
joint_two_bone2d_node = NodePath("Hip/FrontLegTop/FrontLegMid")
joint_two_bone_idx = 5
target_nodepath = NodePath("../Anim Targets/FrontLegIK")

[sub_resource type="SkeletonModification2DLookAt" id="SkeletonModification2DLookAt_front_ankle"]
bone2d_node = NodePath("Hip/FrontLegTop/FrontLegMid/FrontLegBot")
bone_index = 6
target_nodepath = NodePath("../Anim Targets/FrontLegIK/FrontLeg_AT")

[sub_resource type="SkeletonModification2DTwoBoneIK" id="SkeletonModification2DTwoBoneIK_back_leg"]
joint_one_bone2d_node = NodePath("Hip/BackLegTop")
joint_one_bone_idx = 1
joint_two_bone2d_node = NodePath("Hip/BackLegTop/BackLegMid")
joint_two_bone_idx = 2
target_nodepath = NodePath("../Anim Targets/BackLegIK")

[sub_resource type="SkeletonModification2DLookAt" id="SkeletonModification2DLookAt_back_ankle"]
bone2d_node = NodePath("Hip/BackLegTop/BackLegMid/BackLegBot")
bone_index = 3
target_nodepath = NodePath("../Anim Targets/BackLegIK/BackLeg_AT")

[sub_resource type="SkeletonModificationStack2D" id="SkeletonModificationStack2D_darklight2"]
resource_local_to_scene = true
enabled = true
modification_count = 9
modifications/0 = SubResource("SkeletonModification2DLookAt_head")
modifications/1 = SubResource("SkeletonModification2DTwoBoneIK_front_arm")
modifications/2 = SubResource("SkeletonModification2DTwoBoneIK_back_arm")
modifications/3 = SubResource("SkeletonModification2DLookAt_front_wrist")
modifications/4 = SubResource("SkeletonModification2DLookAt_back_wrist")
modifications/5 = SubResource("SkeletonModification2DTwoBoneIK_front_leg")
modifications/6 = SubResource("SkeletonModification2DLookAt_front_ankle")
modifications/7 = SubResource("SkeletonModification2DTwoBoneIK_back_leg")
modifications/8 = SubResource("SkeletonModification2DLookAt_back_ankle")
`;

function generate(source) {
  let lines = source.split("\n");

  const drop = (predicate, what) => {
    const kept = lines.filter((line) => !predicate(line));
    if (kept.length === lines.length) throw new Error(`Nothing matched while removing ${what}`);
    lines = kept;
  };

  // A copy must not claim the canonical scene's uid.
  const header = lines.findIndex((line) => line.startsWith("[gd_scene"));
  if (header < 0) throw new Error("No [gd_scene] header");
  lines[header] = lines[header].replace(/ uid="[^"]*"/, "").replace(/ format=3$/, " format=3");

  // The solver nodes are ordinary @tool Nodes; nothing else addresses them.
  const groupStart = lines.findIndex((line) => line.startsWith('[node name="SoupGroup"'));
  const groupEnd = lines.findIndex((line) => line.startsWith('[node name="Anim Targets"'));
  if (groupStart < 0 || groupEnd <= groupStart) throw new Error("SoupGroup block not found");
  lines.splice(groupStart, groupEnd - groupStart);

  drop((line) => line.includes("res://addons/soupik/"), "the soupik ext_resources");

  // The native stack replaces them one for one.
  const firstSub = lines.findIndex((line) => line.startsWith("[sub_resource"));
  if (firstSub < 0) throw new Error("No sub_resources to anchor the stack on");
  lines.splice(firstSub, 0, ...MODIFICATIONS.split("\n"));

  const skeleton = lines.findIndex((line) => line.startsWith('[node name="Skeleton2D" type="Skeleton2D"'));
  if (skeleton < 0) throw new Error("No Skeleton2D node");
  lines.splice(skeleton + 1, 0, 'modification_stack = SubResource("SkeletonModificationStack2D_darklight2")');

  // ArmPoseControls would re-enable the soupik solvers from its own exports on
  // _ready, so the copy drops them; both arms are IK-only here.
  for (const name of FK_NODES) {
    const index = lines.findIndex((line) => line.startsWith(`[node name="${name}" type="Node2D"`));
    if (index < 0) throw new Error(`No ${name} node`);
    lines[index] = lines[index].replace('"wrist_bone", "arm_ik", "wrist_ik")]', '"wrist_bone")]');
    if (lines[index].includes('"arm_ik"')) throw new Error(`${name} still exports arm_ik`);
    const kept = lines.filter((line, at) => {
      const isOwn = at > index && (line.startsWith("arm_ik =") || line.startsWith("wrist_ik ="));
      return !isOwn;
    });
    if (kept.length !== lines.length - 2) throw new Error(`${name} did not drop both solver exports`);
    lines = kept;
  }

  return lines.join("\n");
}

const expected = generate(readFileSync(SOURCE, "utf8"));

if (CHECK_ONLY) {
  const actual = readFileSync(TARGET, "utf8");
  if (actual === expected) {
    console.log(`${TARGET} is up to date with ${SOURCE}`);
    process.exit(0);
  }
  console.error(`${TARGET} differs from a fresh generation — run: node tests/regenerate_darklight_rig2.mjs`);
  process.exit(1);
}

writeFileSync(TARGET, expected);
console.log(`wrote ${TARGET} (${expected.split("\n").length} lines) from ${SOURCE}`);
