@echo off
setlocal enabledelayedexpansion
prompt $G 
cd /D "%~dp0"
for /F %%a in ('gauche-config --pkglibdir') do set pkglib=%%a
for /F %%a in ('gauche-config --prefix') do set prefix=%%a
set dest=!pkglib:${datadir}=%prefix%\share!
set currentdir=%~dp0
set currentdir=!currentdir:\=\\!
echo (with-module gauche.configure ^
       (fluid-let ((current-load-path ^
                    (lambda() (string-append "%currentdir%" "a")))) ^
         (cf-init) (cf-make-gpd))) | gosh -ugauche.configure --

@echo on
gauche-install -C -m 444 -T "%dest%" ./zip-archive.scm
gauche-install -C -m 444 -T "%dest%\.packages" Gauche-zip-archive.gpd
