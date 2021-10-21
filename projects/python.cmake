set(python_patch_command "")
set(python_configure_command ./configure --prefix=${CMAKE_INSTALL_PREFIX} --enable-shared --enable-ipv6 --without-pymalloc )
set(python_build_command make)
set(python_install_command make install)

if(BUILD_OS_WINDOWS)
    # Otherwise Python will not be able to get external dependencies.
    find_package(Subversion REQUIRED)

    set(python_configure_command )

    # Use the Windows Batch script to pass an argument "/p:PlatformToolset=v140". The argument must have double quotes
    # around it, otherwise it will be evaluated as "/p:PlatformToolset v140" in Windows Batch. Passing this argument
    # in CMake via a command seems to always result in "/p:PlatformToolset v140".
    set(python_build_command cmd /c "${CMAKE_SOURCE_DIR}/projects/build_python_windows.bat" "<SOURCE_DIR>/PCbuild/build.bat" --no-tkinter -c Release -e -M -p x64)
    set(python_install_command cmd /c "${CMAKE_SOURCE_DIR}/projects/install_python_windows.bat amd64 <SOURCE_DIR> ${CMAKE_INSTALL_PREFIX}")

    # The python3.8 build configuration still refers to libffi-7.lib instead of libffi-8.lib which is in the cpython-bin-deps repository it downloads.
    # We patch their .props file to make it refer to libffi-8.lib.
    set(python_patch_command ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/projects/python_libffi_patch.props" "${CMAKE_CURRENT_BINARY_DIR}/Python-prefix/src/Python/PCbuild/libffi.props")

    ExternalProject_Add(Python
        URL https://www.python.org/ftp/python/3.9.7/Python-3.9.7.tgz
        URL_HASH SHA256=a838d3f9360d157040142b715db34f0218e535333696a5569dc6f854604eb9d1
        PATCH_COMMAND ${python_patch_command}
        # The python3.8 build configuration still downloads and installs OpenSSL v1.1.1k from the cpython-bin-deps repository.
        # Thus, we have to force it to use OpenSSL v1.1.1l, as it fixes several security risks
        COMMAND powershell -Command "(gc ${CMAKE_CURRENT_BINARY_DIR}/Python-prefix/src/Python/PCbuild/get_externals.bat) | Foreach-Object { $_ -replace 'openssl-1.1.1k', 'openssl-1.1.1l' -replace 'openssl-bin-1.1.1k-1', 'openssl-bin-1.1.1l' }  | Out-File -encoding ASCII ${CMAKE_CURRENT_BINARY_DIR}/Python-prefix/src/Python/PCbuild/get_externals.bat"
        COMMAND powershell -Command "(gc ${CMAKE_CURRENT_BINARY_DIR}/Python-prefix/src/Python/PCbuild/python.props) | Foreach-Object { $_ -replace 'openssl-1.1.1k', 'openssl-1.1.1l' -replace 'openssl-bin-1.1.1k-1', 'openssl-bin-1.1.1l' }  | Out-File -encoding ASCII ${CMAKE_CURRENT_BINARY_DIR}/Python-prefix/src/Python/PCbuild/python.props"
        CONFIGURE_COMMAND "${python_configure_command}"
        BUILD_COMMAND ${python_build_command}
        INSTALL_COMMAND ${python_install_command}
        BUILD_IN_SOURCE 1
    )
else()
if(BUILD_OS_OSX)
    set(python_configure_command ${python_configure_command} --with-openssl=${CMAKE_INSTALL_PREFIX})
endif()

if(BUILD_OS_LINUX)
    # Set a proper RPATH so everything depending on Python does not need LD_LIBRARY_PATH
    set(python_configure_command LDFLAGS=-Wl,-rpath=${CMAKE_INSTALL_PREFIX}/lib ${python_configure_command} --with-openssl=${CMAKE_INSTALL_PREFIX})
endif()

ExternalProject_Add(Python
    URL https://www.python.org/ftp/python/3.9.7/Python-3.9.7.tgz
    URL_HASH SHA256=a838d3f9360d157040142b715db34f0218e535333696a5569dc6f854604eb9d1
    CONFIGURE_COMMAND "${python_configure_command}"
    BUILD_COMMAND ${python_build_command}
    INSTALL_COMMAND ${python_install_command}
    BUILD_IN_SOURCE 1
)
endif()

# Only build geos on Linux and macOS
# cryptography requires cffi, which requires libffi
if(BUILD_OS_LINUX)
    SetProjectDependencies(TARGET Python DEPENDS OpenBLAS Geos OpenSSL bzip2-static bzip2-shared xz zlib sqlite3 libffi)
elseif(BUILD_OS_OSX)
    SetProjectDependencies(TARGET Python DEPENDS OpenBLAS Geos OpenSSL xz zlib sqlite3 libffi)
else()
    SetProjectDependencies(TARGET Python DEPENDS OpenBLAS)
endif()

# Make sure pip and setuptools are installed into our new Python
ExternalProject_Add_Step(Python ensurepip
    COMMAND ${Python3_EXECUTABLE} -m ensurepip
    DEPENDEES install
)

ExternalProject_Add_Step(Python baserequirements
    COMMAND ${Python3_EXECUTABLE} -m pip install --require-hashes -r  ${CMAKE_SOURCE_DIR}/projects/base_requirements.txt
    DEPENDEES ensurepip
)
