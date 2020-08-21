add_project_arguments(['-DGETTEXT_PACKAGE="' + meson.project_name() + '"'], language : 'c')

conf_data = configuration_data()
conf_data.set('gettext_package', meson.project_name())
conf_data.set('datadir', join_paths(get_option('prefix'), get_option('datadir')))
config_vala = configure_file(input : 'config.vala.in',
			     output : 'config.vala',
			     configuration : conf_data)

sources = files('download.vala', 'main.vala', 'metadata.vala')

executable(meson.project_name(),
	   sources : [config_vala, sources],
	   dependencies : [gtk_dep, json_glib_dep],
	   install : true)
