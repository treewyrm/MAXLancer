/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Initializes/reloads MAXLancer scripts.
 */
macroscript ReloadScripts category:"MAXLancer" tooltip:"Reload Scripts" buttontext:"Reload Scripts" iconName:"MAXLancer/toolbar" (
	global MAXLancer

	on execute do (
		local previousDir = sysInfo.currentDir
		local filename    = "MAXLancer/MAXLancer.ms"
		local mainScript  = pathConfig.appendPath (GetDir #userScripts) filename

		if not doesFileExist mainScript then mainScript = pathConfig.appendPath (GetDir #scripts) filename

		MAXLancer == undefined

		if doesFileExist mainScript then (
			try (
				sysInfo.currentDir = getFilenamePath mainScript
				fileIn mainScript
				sysInfo.currentDir = previousDir
				
				if MAXLancer == undefined then messageBox ("Unable to initialize MAXLancer.") else
					displayTempPrompt "MAXLancer scripts reloaded" 2000

			) catch (
				messageBox (getCurrentException())
				MAXLancer = undefined
				throw()
			)
		) else messageBox ("Missing MAXLancer script:\r\n" + mainScript)
	)
)