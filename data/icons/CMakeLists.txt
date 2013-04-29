### CMakeLists automatically created with AutoVala
### Do not edit

if(${CMAKE_INSTALL_PREFIX} MATCHES usr/local/? )
	set( AUTOVALA_INSTALL_PREFIX "/usr/local")
else()
	set( AUTOVALA_INSTALL_PREFIX "/usr")
endif()

STRING (REPLACE "/" ";" AUTOVALA_PATH_LIST ${CMAKE_INSTALL_PREFIX})
SET (FINAL_AUTOVALA_PATH "")

FOREACH(element ${AUTOVALA_PATH_LIST})
	IF (${FOUND_USR})
		SET(FINAL_AUTOVALA_PATH ${FINAL_AUTOVALA_PATH}/.. )
	ELSE()
		IF(${element} STREQUAL "usr")
			SET(FOUND_USR 1)
			SET(FINAL_AUTOVALA_PATH ${FINAL_AUTOVALA_PATH}.. )
		ENDIF()
	ENDIF()
ENDFOREACH()

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/pequerrechos_fine.svg DESTINATION share/icons/hicolor/scalable/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/pequerrechos_notime.svg DESTINATION share/icons/hicolor/scalable/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/pequerrechos_lesstime.svg DESTINATION share/icons/hicolor/scalable/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/pequerrechos_disabled.svg DESTINATION share/icons/hicolor/scalable/apps/)

IF(NOT (DEFINED ICON_UPDATE))
	SET (ICON_UPDATE "ON")
ENDIF()
IF( NOT (${ICON_UPDATE} STREQUAL "OFF" ))
	install (CODE "execute_process ( COMMAND /usr/bin/gtk-update-icon-cache-3.0 -t ${CMAKE_INSTALL_PREFIX}/share/icons/hicolor )" )
ENDIF()
