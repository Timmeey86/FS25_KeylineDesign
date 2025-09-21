use cavalier_contours::polyline::*;
use yaserde_derive::{YaDeserialize, YaSerialize};
use notify::{Event, Result, Watcher};
use std::path::Path;
use std::sync::mpsc;

// Define structures which match the keyline import and the parallel line export
#[derive(Debug, YaSerialize, YaDeserialize, PartialEq, Clone)]
struct Coords {
	#[yaserde(attribute=true)]
	pub x: f64,
	#[yaserde(attribute=true)]
	pub z: f64,
}

#[derive(Debug, YaDeserialize)]
struct FieldBoundary {
	#[yaserde(rename="coords")]
	coords: Vec<Coords>,
}

#[derive(Debug, YaDeserialize)]
struct Settings {
	#[yaserde(rename="headlandWidth", attribute=true)]
	pub headland_width: u16,
	#[yaserde(rename="stripWidth", attribute=true)]
	pub strip_width: u16,
	#[yaserde(rename="keylineWidth", attribute=true)]
	pub keyline_width: u16,
	#[yaserde(rename="numLinesRight", attribute=true)]
	pub num_lines_right: u16,
	#[yaserde(rename="numLinesLeft", attribute=true)]
	pub num_lines_left: u16,
}

#[derive(Debug, YaDeserialize)]
#[yaserde(rename="keylines")]
struct Keylines {
	#[yaserde(rename="keyline")]
	keylines: Vec<Keyline>,
	#[yaserde(rename="fieldBoundary")]
	field_boundary: FieldBoundary,
	#[yaserde(rename="settings")]
	settings: Settings,
}

#[derive(Debug, YaDeserialize)]
struct Keyline {
	#[yaserde(rename="coords")]
	coords: Vec<Coords>,
}

#[derive(Debug, YaSerialize)]
#[yaserde(rename="parallelLines")]
struct ParallelLines {
	#[yaserde(rename="parallelLine")]
	parallel_lines: Vec<ParallelLine>,
}

#[derive(Debug, YaSerialize)]
struct ParallelLine {
	#[yaserde(rename="coords")]
	coords: Vec<Coords>,
}

fn generate_parallel_lines(
	coords: &Vec<Coords>,
	num_lines: u16,
	distance: u16,
	direction: i32,
) -> ParallelLines {
	let mut parallel_lines = ParallelLines { parallel_lines: Vec::new() };
	let mut pline = Polyline::with_capacity(coords.len(), false);
	for coord in coords {
		pline.add(coord.x, coord.z, 0.0);
	}
	// Generate parallel offset lines as desired
	for i in 1..=num_lines {
		let offset_distance = distance as f64 * i as f64 * direction as f64;
		let offset_plines = pline.parallel_offset(offset_distance);
		for offset_pline in offset_plines {
			let mut coords = Vec::new();
			for point in offset_pline.vertex_data {
				coords.push(Coords { x: point.x, z: point.y });
			}
			parallel_lines.parallel_lines.push(ParallelLine { coords });
		}
	}
	parallel_lines
}

fn point_in_polygon(coord: &Coords, polygon: &[Coords]) -> bool {
	let mut inside = false;

	if polygon.len() < 3 {
		return false;
	}

	// Drop the duplicate last point if present
	let n = if polygon.first().zip(polygon.last()).map_or(false, |(a, b)| a == b) {
		polygon.len() - 1
	} else {
		polygon.len()
	};

	for i in 0..n {
		let j = (i + 1) % n;
		let (xi, zi) = (polygon[i].x, polygon[i].z);
		let (xj, zj) = (polygon[j].x, polygon[j].z);

		let intersects = ((zi > coord.z) != (zj > coord.z)) &&
						(coord.x < (xj - xi) * (coord.z - zi) / (zj - zi) + xi);

		if intersects {
			inside = !inside;
		}
	}

	inside
}

fn split_lines_inside_polygon(parallel_lines: &ParallelLines, boundary_polygon: &[Coords]) -> Vec<ParallelLine> {
	let mut new_parallel_lines = Vec::new();

	for pline in &parallel_lines.parallel_lines {
		let mut current_coords = Vec::new();
		let mut inside = false;

		for coord in &pline.coords {
			let is_inside = point_in_polygon(coord, boundary_polygon);

			if is_inside {
				current_coords.push(coord.clone());
				inside = true;
			} else if inside {
				// Just exited the polygon, finish the current line
				if current_coords.len() >= 2 {
					new_parallel_lines.push(ParallelLine { coords: current_coords.clone() });
				}
				current_coords.clear();
				inside = false;
			}
			// If not inside, just skip the point
		}

		// If the last segment was inside, push it
		if current_coords.len() >= 2 {
			new_parallel_lines.push(ParallelLine { coords: current_coords });
		}
	}

	new_parallel_lines
}

fn resample_line_to_equal_spacing(coords: &Vec<Coords>, spacing: f64) -> Vec<Coords> {
	let mut new_coords = Vec::new();
	if coords.len() < 2 {
		return new_coords;
	}
	let first_coord = &coords[0];
	new_coords.push(Coords { x: first_coord.x, z: first_coord.z });
	let mut last_length: f64 = 0.0;
	for i in 0..coords.len() - 1 {
		let x = coords[i].x;
		let z = coords[i].z;
		let next_x = coords[i + 1].x;
		let next_z = coords[i + 1].z;
		let dx = next_x - x;
		let dz = next_z - z;

		let mut segment_length = (dx * dx + dz * dz).sqrt();
		if segment_length == 0.0 {
			continue;
		}

		segment_length += last_length;

		let num_segments = (segment_length / spacing).floor() as usize;
		let step_x = dx / segment_length * spacing;
		let step_z = dz / segment_length * spacing;

		for j in 1..=num_segments {
			let new_x = x + step_x * j as f64;
			let new_z = z + step_z * j as f64;
			new_coords.push(Coords { x: new_x, z: new_z });
		}

		last_length = segment_length - num_segments as f64 * spacing;
	}
	let last_coord = coords.last().unwrap();
	new_coords.push(Coords { x: last_coord.x, z: last_coord.z });
	new_coords
}

fn process_keylines_xml(keylines_path: &str, savegame_path: &str) {
	// Deserialize the keylines.xml file
	let keylines_file = std::fs::File::open(&keylines_path).expect("Failed to open keylines.xml");
	let mut keylines: Keylines = yaserde::de::from_reader(keylines_file).expect("Failed to parse keylines.xml");
	println!("Found {} keylines.", keylines.keylines.len());

	// Round keyline coords to 5 decimal places to avoid floating point precision issues
	for keyline in &mut keylines.keylines {
		for coord in &mut keyline.coords {
			coord.x = (coord.x * 100000.0).round() / 100000.0;
			coord.z = (coord.z * 100000.0).round() / 100000.0;
		}
	}
	for coord in &mut keylines.field_boundary.coords {
		coord.x = (coord.x * 100000.0).round() / 100000.0;
		coord.z = (coord.z * 100000.0).round() / 100000.0;
	}

	// Get settings from keylines
	let headland_width = &keylines.settings.headland_width;
	let strip_width = &keylines.settings.strip_width;
	let keyline_width = &keylines.settings.keyline_width;
	let num_lines_right = &keylines.settings.num_lines_right;
	let num_lines_left = &keylines.settings.num_lines_left;
	println!("Genereting parallel lines with the following settings:");
	println!("Headland width: {}, Strip width: {}, Keyline width: {}", headland_width, strip_width, keyline_width);

	// Generate parallel lines to the keyline
	let parallel_lines1 = generate_parallel_lines(&keylines.keylines[0].coords, *num_lines_right, strip_width + keyline_width, 1);
	let parallel_lines2 = generate_parallel_lines(&keylines.keylines[0].coords, *num_lines_left, strip_width + keyline_width, -1);
	// combine both sets as well as the initial keyline into a single ParallelLines struct
	let mut parallel_lines = parallel_lines1;
	parallel_lines.parallel_lines.extend(parallel_lines2.parallel_lines);
	parallel_lines.parallel_lines.push(ParallelLine { coords: keylines.keylines[0].coords.clone() });

	let parallel_boundary = generate_parallel_lines(&keylines.field_boundary.coords, 1, *headland_width, 1);

	// Cut away any points which are outside of the polygon defined by parallel_boundary.
	// If points were cut off, but then new points are inside the polygon again, split the line into multiple lines
	let boundary_polygon = &parallel_boundary.parallel_lines[0].coords;
	parallel_lines.parallel_lines = split_lines_inside_polygon(&parallel_lines, boundary_polygon);

	// For every parallel line, redefine the coordinates so they all have an equal spacing of 1 unit
	for pline in &mut parallel_lines.parallel_lines {
		pline.coords = resample_line_to_equal_spacing(&pline.coords, 1.0);
	}

	// Serialize the parallel lines to parallel_lines.xml
	let parallel_lines_path = format!("{}/parallel_lines.xml", savegame_path);
	let mut parallel_lines_file = std::fs::File::create(&parallel_lines_path).expect("Failed to create parallel_lines.xml");
	let yaserde_cfg = yaserde::ser::Config {
		perform_indent: true,
		..Default::default()
	};
	yaserde::ser::serialize_with_writer(&parallel_lines, &mut parallel_lines_file, &yaserde_cfg).expect("Failed to write parallel_lines.xml");
	println!("Wrote {} parallel lines to parallel_lines.xml", parallel_lines.parallel_lines.len());
}

fn main() -> Result<()>{
	let args: Vec<String> = std::env::args().collect();
	let savegame_id = &args[1];
	println!("Savegame ID: {}", savegame_id);

	// Get the path to the user directory
	let user_dir = std::env::var("USERPROFILE").unwrap();
	// Build the path to the FS25 save game directories
	let savegame_path = format!("{}/Documents/My Games/FarmingSimulator2025/savegame{}", user_dir, savegame_id);
	println!("Savegame path: {}", savegame_path);

	// Find the keylines.xml and watch for changes, even if it doesn't exist yet
	let keylines_path = format!("{}/keylines.xml", savegame_path);
	let (tx, rx) = mpsc::channel::<Result<Event>>();
	let mut keylines_watcher = notify::recommended_watcher(tx)?;

	keylines_watcher.watch(Path::new(&keylines_path), notify::RecursiveMode::NonRecursive)?;
	// Watch for changes indefinitely
	// Note that Farming Simulator causes to Modify(Any) events, with identical flags,
	// so we need to skip each first event
	let mut skip_event = true;
	for res in rx {
		if skip_event {
			skip_event = false;
		} else {
			skip_event = true;
			match res {
				Ok(_event) => {
					if let Err(e) = std::panic::catch_unwind(|| {
						process_keylines_xml(&keylines_path, &savegame_path)
					}) {
						println!("Failed generating keylines. Try another location: {:?}", e);
					}
				}
				Err(e) => println!("watch error: {:?}", e),
			}
		}
	}

	Ok(())
}