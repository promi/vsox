gtk_dep = dependency('gtk+-3.0')
gee_dep = dependency('gee-0.8')
posix_dep = meson.get_compiler('vala').find_library('posix')

vsox_exe = executable('vsox',
                      'vsox.vala',
                      install: true,
                      dependencies: [gtk_dep, gee_dep, posix_dep])
