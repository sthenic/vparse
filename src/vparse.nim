when is_main_module:
   when defined(pylib):
      include ./vparsepkg/private/pylib/vparse
   else:
      include ./vparsepkg/private/app
else:
   import ./vparsepkg/graph
   export graph
