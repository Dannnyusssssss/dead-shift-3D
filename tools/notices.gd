extends SceneTree
## Escribe el aviso de licencias que se publica junto al juego (build/web/LICENCIAS.txt): el de
## Dead Shift 3D y los recursos de terceros (docs/LICENSES.md) y el del motor Godot con todos sus
## componentes, tal como los declara el propio motor.
##   godot --headless --path . -s res://tools/notices.gd -- <archivo de salida>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("falta el archivo de salida")
		quit(2)
		return
	var lines: PackedStringArray = []
	lines.append("Dead Shift 3D - avisos de licencia")
	lines.append("=================================")
	lines.append("")
	lines.append(FileAccess.get_file_as_string("res://LICENSE").strip_edges())
	lines.append("")
	lines.append(FileAccess.get_file_as_string("res://docs/LICENSES.md").strip_edges())
	lines.append("")
	lines.append("Godot Engine")
	lines.append("------------")
	lines.append(Engine.get_license_text().strip_edges())
	lines.append("")
	lines.append("Componentes de terceros incluidos en el motor")
	lines.append("---------------------------------------------")
	for component: Dictionary in Engine.get_copyright_info():
		lines.append("")
		lines.append(str(component.get("name", "")))
		for part: Dictionary in component.get("parts", []):
			for holder: String in part.get("copyright", PackedStringArray()):
				lines.append("  Copyright " + holder)
			lines.append("  Licencia: " + str(part.get("license", "")))
	var licenses := Engine.get_license_info()
	for license_name: String in licenses:
		lines.append("")
		lines.append("Licencia " + license_name)
		lines.append(str(licenses[license_name]).strip_edges())
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("no se pudo escribir " + args[0])
		quit(1)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
	quit(0)
