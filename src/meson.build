sources = files('main.vala', 'metadata.vala')

executable(meson.project_name(),
	   sources : sources,
	   dependencies : [gtk_dep, json_glib_dep],
	   install : true)
