when is_main_module:
   when not defined(lib):
      include ./vparsepkg/private/app
   else:
      include ./vparsepkg/private/lib
else:
   import ./vparsepkg/graph
   export graph
