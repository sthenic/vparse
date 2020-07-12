when is_main_module:
   when defined(lib):
      include ./vparsepkg/private/lib
   elif defined(pylib):
      include ./vparsepkg/private/pylib/vparse
   else:
      include ./vparsepkg/private/app
else:
   import ./vparsepkg/graph
   export graph
