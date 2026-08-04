from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "enemies" / "bosses" / "generated"


def split(
	source_name: str,
	columns: int,
	rows: int,
	names: list[str],
	inset: int = 2,
	version: str = "v3",
) -> None:
	image = Image.open(ASSET_DIR / source_name).convert("RGBA")
	cell_width = image.width // columns
	cell_height = image.height // rows
	for index, name in enumerate(names):
		column = index % columns
		row = index // columns
		left = column * cell_width + inset
		top = row * cell_height + inset
		right = (column + 1) * cell_width - inset
		bottom = (row + 1) * cell_height - inset
		image.crop((left, top, right, bottom)).save(ASSET_DIR / f"six_arm_oni_{name}_{version}.png")


split(
	"six_arm_oni_core_v3.png",
	2,
	2,
	["upper_skull_kabuto", "lower_jaw", "six_socket_torso", "smoke_pelvis"],
)
split(
	"six_arm_oni_limbs_v3.png",
	3,
	3,
	[
		"left_upper_arm",
		"left_forearm",
		"left_hand_katana_up",
		"right_upper_arm",
		"right_forearm",
		"right_hand_katana_up",
		"left_hand_katana_down",
		"right_hand_katana_down",
		"cyan_flame_effects",
	],
)
split(
	"six_arm_oni_skeletal_body_v4.png",
	2,
	1,
	["skeletal_torso", "skeletal_smoke_pelvis"],
	version="v4",
)
split(
	"six_arm_oni_joint_limbs_v4.png",
	3,
	2,
	[
		"left_upper_arm",
		"left_forearm",
		"left_hand_katana_up",
		"right_upper_arm",
		"right_forearm",
		"right_hand_katana_up",
	],
	version="v4",
)
