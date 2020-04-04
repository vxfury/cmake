# compiler flags
SET(compiler_flags)

IF(CMAKE_BUILD_TYPE STREQUAL "Debug")
    ADD_DEFINITIONS(-D__DEBUG__)
    IF(("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang") OR ("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU"))
        LIST(APPEND compiler_flags -g -O0)
    ELSEIF("${CMAKE_C_COMPILER_ID}" STREQUAL "MSVC")
        LIST(APPEND compiler_flags /O0)
    ENDIF()
ELSE()
    ADD_DEFINITIONS(-D__RELEASE__ -DNDEBUG)
    IF(("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang") OR ("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU"))
        LIST(APPEND compiler_flags -O3)
    ELSEIF("${CMAKE_C_COMPILER_ID}" STREQUAL "MSVC")
        LIST(APPEND compiler_flags /O3)
    ENDIF()
ENDIF()

OPTION(ENABLE_STATIC_CHECK "Enables static checking compiler flags" OFF)
IF(ENABLE_STATIC_CHECK)
    IF(
        ("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang") OR ("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU")
        OR ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang") OR ("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU")
    )
        LIST(APPEND compiler_flags
            -Wall
            -Wno-pragmas
            -Wno-unknown-pragmas
            -pedantic
            -Wcast-align
            -Wcast-qual
            -Wswitch-enum
            -Wswitch-default
            -Wextra
            -Wstrict-prototypes
            -Wmissing-prototypes
            -Wmissing-variable-declarations
            -Wwrite-strings
            -Wshadow
            -Winit-self
            -Wformat=2
            -Wstrict-overflow=2
            -Wundef
            -Wconversion
            -Wc++-compat
            -fstack-protector-strong
            -Wcomma
            -Wdouble-promotion
            -Wparentheses
            -Wformat-overflow
            -Wunused-macros
            -Wused-but-marked-unused
        )
    ELSEIF("${CMAKE_C_COMPILER_ID}" STREQUAL "MSVC")
        # Disable warning c4001 - nonstandard extension 'single line comment' was used
        # Define _CRT_SECURE_NO_WARNINGS to disable deprecation warnings for "insecure" C library functions
        LIST(APPEND compiler_flags
            /GS
            /Za
            /sdl
            /W4
            /wd4001
            /D_CRT_SECURE_NO_WARNINGS
        )
    ENDIF()
ENDIF()

OPTION(ENABLE_SANITIZERS "Enables AddressSanitizer and UndefinedBehaviorSanitizer." OFF)
IF(ENABLE_SANITIZERS)
    LIST(APPEND compiler_flags
        -fno-omit-frame-pointer
        -fsanitize=address
        -fsanitize=undefined
        -fsanitize=float-divide-by-zero
        -fsanitize=float-cast-overflow
        -fsanitize=integer
        -fno-sanitize-recover=all
    )
ENDIF()

OPTION(ENABLE_SAFE_STACK "Enables the SafeStack instrumentation pass by the Code Pointer Integrity Project" OFF)
IF(ENABLE_SAFE_STACK)
    IF(ENABLE_SANITIZERS)
        MESSAGE(FATAL_ERROR "ENABLE_SAFE_STACK cannot be used in combination with ENABLE_SANITIZERS")
    ENDIF()
    LIST(APPEND compiler_flags
        -fsanitize=safe-stack
    )
ENDIF()

OPTION(ENABELE_POSITION_INDEPENDENT_CODE "Enable Position Independent Code" ON)
IF(ENABELE_POSITION_INDEPENDENT_CODE)
    LIST(APPEND compiler_flags -fPIC)
ENDIF()

OPTION(ENABLE_PUBLIC_SYMBOLS "Export library symbols." OFF)
IF(ENABLE_PUBLIC_SYMBOLS)
    LIST(APPEND compiler_flags -fvisibility=hidden)
    ADD_DEFINITIONS(-DAPI_VISIBILITY)
ENDIF()

# coverage check
OPTION(ENABLE_COVERAGE_CHECK "Enable Coverage check" OFF)
IF(ENABLE_COVERAGE_CHECK)
	ADD_DEFINITIONS(-coverage)
ENDIF()


# try conditional compilation
OPTION(ENABLE_CHECK_C_FLAGS "Enable CCompilerFlag checking" ON)
SET(supported_c_flags)
INCLUDE(CheckCCompilerFlag)
IF(ENABLE_CHECK_C_FLAGS)
    FOREACH(compiler_flag ${compiler_flags})
        CHECK_C_COMPILER_FLAG(${compiler_flag} "C${compiler_flag}")
        IF(C${compiler_flag})
            LIST(APPEND supported_c_flags ${compiler_flag})
        ENDIF()
    ENDFOREACH()
ENDIF()

OPTION(ENABLE_CHECK_CXX_FLAGS "Enable CXXCompilerFlag checking" OFF)
SET(supported_cxx_flags)
INCLUDE(CheckCXXCompilerFlag)
IF(ENABLE_CHECK_CXX_FLAGS)
    FOREACH(compiler_flag ${compiler_flags})
        CHECK_CXX_COMPILER_FLAG(${compiler_flag} "CXX${compiler_flag}")
        IF(CXX${compiler_flag})
            LIST(APPEND supported_cxx_flags ${compiler_flag})
        ENDIF()
    ENDFOREACH()
ENDIF()

FUNCTION(CHOOSE_LANG_FLAGS lang selected)
    FOREACH(arg IN LISTS ARGN)
        IF("${lang}" STREQUAL "C")
            CHECK_C_COMPILER_FLAG(${arg} ${lang}${arg})
        ELSEIF("${lang}" STREQUAL "CXX")
            CHECK_CXX_COMPILER_FLAG(${arg} ${lang}${arg})
        ELSE()
            BREAK()
        ENDIF()
        IF(${lang}${arg})
            SET(${selected} ${arg} PARENT_SCOPE)
            RETURN()
        ENDIF()
    ENDFOREACH()
    SET(${selected} "" PARENT_SCOPE)
ENDFUNCTION()

# CMAKE_C${std}_STANDARD_COMPILE_OPTION}, CMAKE_C${std}_EXTENSION_COMPILE_OPTION} for std in (90 99 11 18)
CHOOSE_LANG_FLAGS(C selected "-std=gnu18" "-std=c18" "-std=gnu11" "-std=c11" "-std=gnu99" "-std=c99")
IF(NOT (selected STREQUAL ""))
    LIST(APPEND supported_c_flags ${selected})
ELSE()
    MESSAGE(STATUS "The compiler ${CMAKE_C_COMPILER} has no GNU99 or STD99 support. Please use a different C compiler.")
ENDIF()

# CMAKE_CXX${std}_STANDARD_COMPILE_OPTION}, CMAKE_CXX${std}_EXTENSION_COMPILE_OPTION} for std in (11 14 17 20)
CHOOSE_LANG_FLAGS(CXX selected "-std=gnu++2a" "-std=c++2a" "-std=gnu++1z" "-std=c++1z" "-std=gnu++14" "-std=c++14" "-std=gnu++11" "-std=c++11")
IF(NOT (selected STREQUAL ""))
    LIST(APPEND supported_cxx_flags ${selected})
ELSE()
    MESSAGE(STATUS "The compiler ${CMAKE_CXX_COMPILER} has no c++20/c++17/c++14/c++11 support. Please use a different C++ compiler.")
ENDIF()

STRING(REPLACE ";" " " CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${supported_c_flags}")
STRING(REPLACE ";" " " CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${supported_cxx_flags}")


# useful utilities
## redefine __FILE__ after stripping project dir
FUNCTION(TARGET_REMOVE_SOURCE_PREFIX target)
    TARGET_COMPILE_OPTIONS(${target} PUBLIC -Wno-builtin-macro-redefined)
    # Get source files of target
    GET_TARGET_PROPERTY(source_files ${target} SOURCES)
    FOREACH(sourcefile ${source_files})
        # Get compile definitions in source file
        GET_PROPERTY(defs SOURCE "${sourcefile}" PROPERTY COMPILE_DEFINITIONS)
        # Get absolute path of source file
        GET_FILENAME_COMPONENT(filepath "${sourcefile}" ABSOLUTE)
        # Trim leading dir according to ${PROJECT_SOURCE_DIR}
        STRING(REPLACE ${PROJECT_SOURCE_DIR}/ "" relpath ${filepath})
        # Add __FILE__ definition to compile definitions
        LIST(APPEND defs "__FILE__=\"${relpath}\"")
        # Set compile definitions to property
        SET_PROPERTY(SOURCE "${sourcefile}" PROPERTY COMPILE_DEFINITIONS ${defs})
    ENDFOREACH()
ENDFUNCTION()


# Things like checking for headers, functions, libraries, types and size of types.
INCLUDE(${CMAKE_ROOT}/Modules/CheckIncludeFile.cmake)
INCLUDE(${CMAKE_ROOT}/Modules/CheckTypeSize.cmake)
INCLUDE(${CMAKE_ROOT}/Modules/CheckFunctionExists.cmake)
INCLUDE(${CMAKE_ROOT}/Modules/CheckCXXSourceCompiles.cmake)
INCLUDE(${CMAKE_ROOT}/Modules/TestBigEndian.cmake)
INCLUDE(${CMAKE_ROOT}/Modules/CheckSymbolExists.cmake)

# check the size of primitive types
CHECK_TYPE_SIZE("long" SIZEOF_LONG)
MATH(EXPR BITS_PER_LONG "8 * ${SIZEOF_LONG}")

# check for include files
# CHECK_INCLUDE_FILE("sys/prctl.h" HAVE_SYS_PRCTL_H)

# check for functions/symbols
# LIST(APPEND CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)
# LIST(APPEND CMAKE_REQUIRED_LIBRARIES pthread)
# CHECK_SYMBOL_EXISTS(pthread_setname_np pthread.h HAVE_PTHREAD_SETNAME_NP)
# CHECK_SYMBOL_EXISTS(pthread_getname_np pthread.h HAVE_PTHREAD_GETNAME_NP)
# LIST(REMOVE_ITEM CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)
# CHECK_FUNCTION_EXISTS("prctl" HAVE_PRCTL)
