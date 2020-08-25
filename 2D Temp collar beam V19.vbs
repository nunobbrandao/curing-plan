$ENGINE=VBScript
' LUSAS Modeller session file
' Created by LUSAS 18.1-1c2 - Modeller Version 18.1.1617.32867
' Created at 13:48 on Thursday, June 11 2020
' (C) Finite Element Analysis Ltd 2020
' written by Nuno B Brandao on the 16/06/2020
call setCreationVersion("18.1-1c2, 18.1.1617.32867")

'**********************************************************************************************************
'** Code: it runs different analyses for different concrete formulations.
'**********************************************************************************************************

'variables:
w = InputBox("Enter next result ID number (set w=2 when LUSAS opened on 1st time)")

'set cement properties:
Dim cement_form(1,2)
'formulation 0	
cement_form(0,0) = 235  'mass of cement per unit volume
cement_form(0,1) = 0.50 'w/c
cement_form(0,2) = 235  'mass of slag per meter volume      
'formulation 1					    
cement_form(1,0) = 144  'mass of cement per unit volume        
cement_form(1,1) = 0.50 'w/c          
cement_form(1,2) = 336  'mass of slag per meter volume             

'set when 2nd pour unfolds in hours:   
sec_pour_time = Array (72, 96, 120, 144, 168, 192, 216, 1) 

'set placing temperatures in celsius
placing_temperature = Array(20,28,35)'Array(20,28,35)

'set ambient temperature in celsius
ambient_temperature = 15

'set what time formwork remotion after 2nd pour unfolds in hours
remotion_formwork_after_2ndpour = 216'14*24

'code:
'loop on different placing temperatures for the concrete
for each place_temp in placing_temperature	
	'exit if w is inexistent 
	If IsNull(w)  Or  IsEmpty(w) Then
		Exit For 
	End If
	'set ambient and placing temperatures
	call set_placing_temperature("PlacingTemp beam", place_temp)
	call set_placing_temperature("PlacingTemp infill", ambient_temperature)
	call set_thermal_loading("formwork_left", ambient_temperature, 5.2)
	call set_thermal_loading("formwork_top", ambient_temperature, 5.2)
	call set_thermal_loading("Outside", ambient_temperature, 21.6)
	call set_thermal_loading("concrete dwall (thick = 1)", ambient_temperature, 1.0)
	call set_thermal_loading("concrete slab (thick =2.5)", ambient_temperature, 0.4)
	
	'loop on different 2nd pour timings
	For Each pour In sec_pour_time
		'loadcurves timings
		call loadcurve_timing("PlacingTemp beam", 0, 5e3)
		call loadcurve_timing("Formwork", 0, pour + remotion_formwork_after_2ndpour - 0.001)
		call loadcurve_timing("After Formwork", pour + remotion_formwork_after_2ndpour, 5e3)
		call loadcurve_timing("Formwork + After Formwork", 0, 5e3)
		call loadcurve_timing("1st and 2nd pour joint", 0, pour-.001)	
		'loadcase timings
		call first_pour_totaltime("1st pour thermal life", pour, .5)	
		
		'loop on different cement formulations
		For i = 0 To UBound(cement_form,1)
			set attr = database.createFieldIsoMaterial("Concrete_thermal")
			call attr.setPhaseChange("None")
			call attr.addConcreteMaterial(1.4, 0.0, 1.0E3, 0.0, "Type I", cement_form(i,0), cement_form(i,1), cement_form(i,2), 0.0, 0.0, 0.0, 2.5E3)
			call run_analysis("Thermal","Thermal")
			call set_printwizard()
			call print_printwizard(w, i, pour, place_temp, remotion_formwork_after_2ndpour)
			call close_printwizard(w)
			w = w+1
		next
	next
next

getTextWindow().WriteLine("*********Code has run successfully*********")

'**********************************************************************************************************
'** Subrotines:
'**********************************************************************************************************

'Set  PrintWizard:
Sub set_printwizard()
	set attr = nothing
	set attr = database.createPrintResultsWizard("PRW1")
	call attr.setResultsType("Components")
	call attr.setResultsOrder("Mesh")
	call attr.setResultsContent("Tabular")
	call attr.setResultsEntity("Potential")
	call attr.setExtent("Full model", "")
	call attr.setResultsLocation("Nodal")
	call attr.setLoadcasesOption("All")
	redim components(0)
	components(0) = "PHI"
	call attr.setComponents(components)
	redim primaryComponents(0)
	redim primaryEntities(0)
	primaryComponents(0) = "All"
	primaryEntities(0) = "Displacement"
	call attr.setPrimaryResultsData(primaryComponents, primaryEntities)
	call attr.setAnalysisResultTypes(Nothing)
	call attr.setResultsTransformNone()
	call attr.showCoordinates(true)
	call attr.showExtremeResults(false)
	call attr.setSlice(false)
	call attr.setAllowDerived(false)
	call attr.setDisplayNow(false)
	call attr.setSigFig(6, false)
	call attr.setThreshold(Nothing)
	set attr = nothing
end sub

'Print  PrintWizard:
Sub print_printwizard(w, i, pour,place_temp,fw_rem_time)
	set attr = database.getAttribute("Print Results Wizard", "PRW1")
	call attr.showResults()
	set attr = nothing
	'call getGridWindowByID(w).setCurrentTab("Model info")
	call getGridWindowByID(w).setCurrentTab("1:Thermal Initialization - 1:Time Step 0 Time = 0.000000E+00")
	call getGridWindowByID(w).saveAllAs(getCWD() & "\cement" & i & "place_temp" & place_temp & "at" & pour &"fw_rem" & fw_rem_time & ".txt", "Text")
end sub

'close  PrintWizard:
Sub close_printwizard(w)
	call getGridWindowByID(w).close()
	set attr = database.getAttribute("Print Results Wizard", "PRW1")
	call database.deleteAttribute(attr)
	set attr = nothing
End Sub

'Run Analysis:
sub run_analysis(element_type, analysis)
	call database.closeAllResults()
	call database.updateMesh()
	exportErrors = 0
	solverErrors = 0
	call solverOptions.setAllDefaults()
	call solverExport.setAllDefaults()
	call solverExport.setFilename("%DBFolder%\%ModelName%~" & analysis & ".dat")
	call solverExport.setElementType(element_type)
	call solverExport.setAnalysis(analysis)
	exportErr = database.exportSolver(solverExport, solverOptions)
	if (exportErr <> 0) then
		exportErrors = exportErr
	end if
	if (exportErr = 0) then
		solveErr = solve("%DBFolder%\%ModelName%~" & analysis & ".dat", solverOptions)
		if (solveErr <> 0) then
			solverErrors = solveErr
		end if
		call fileOpen("%PerMachineAppDataPlatform%\config\AfterSolve")
		call scanout("%DBFolder%\%ModelName%~" & analysis & ".out")
	end if
	if (exportErr = 0) then
		call database.openResults("%DBFolder%\%ModelName%~" & analysis & ".mys", analysis, false, 0, false, false)
	end if
	call processSolveErrors(exportErrors, solverErrors)
End Sub

'Set loadcurves timings:
sub loadcurve_timing(name, start, finish)
	'name - name of the loadcurve_timing
	'duration of the load curve
	set loadCurve = database.createLoadCurveTable(name, 0.0, 1.0, "Thermal", 0)
	redim x(1)
	redim y(1)
	x(0) = start*3600
	y(0) = 1.0
	x(1) = finish*3600
	y(1) = 1.0
	call loadCurve.setTableData(x, y)
	erase x
	erase y
	call loadCurve.setIntegration(false)
	set loadCurve = nothing
end sub

'set loadcase timing
sub first_pour_totaltime(name, TotalResponseTime, InitialTimeStep)
	set loadcase = database.getLoadset(name, 0)
	call loadcase.setTransientControl(10000)
	call loadcase.getTransientControl().setValue("CouplingReadInterval", 1.8E3).setValue("CouplingWriteInterval", 1.8E3)
	call loadcase.getTransientControl().setNonlinearManual().setValue("GeostaticStep", false)
	call loadcase.getTransientControl().setValue("AllowStepReduction", true).setValue("MaxStepReduction", 5)
	call loadcase.getTransientControl().setTimeDomainThermal(InitialTimeStep*3600)
	call loadcase.getTransientControl().setValue("TimeStepRestrictionFactor", 1.05).setValue("MinTimeStepFactor", 36.0).setValue("MaxTimeStepFactor", 18.0E3)
	call loadcase.getTransientControl().setValue("TotalResponseTime", TotalResponseTime*3600).setValue("MinTimeStep", 0.0)
	call loadcase.getTransientControl().setConstants().setValue("nit", 200).setValue("nalps", 2).setValue("toline", 0.75).setValue("rmaxal", 100.0E6)
	call loadcase.getTransientControl().setValue("rnoral", 100.0E6).setValue("dlnorm", 1.0).setValue("rlnorm", 0.1).setValue("wlnorm", 100.0E6)
	call loadcase.getTransientControl().setValue("dtnrml", 1.0).setValue("ampmx", 5.0).setValue("etmxa", 25.0).setValue("etmna", 0.0)
	call loadcase.getTransientControl().setValue("alpha", 0.0).setValue("beta", 1.0).setValue("gamma", 0.5).setValue("isilcp", false)
	call loadcase.getTransientControl().setValue("pnrm", 0.0).setValue("ptnrm", 0.0).setValue("tnorm", 0.0).setValue("pnorm", 0.0)
	call loadcase.getTransientControl().setOutput().setValue("IncrementIntervalForLusas", 1).setValue("IncrementIntervalForPlotFile", 1).setValue("IncrementIntervalForRestart", 0)
	call loadcase.getTransientControl().setValue("MaxRestartDumpsSaved", 0).setValue("IncrementIntervalForTimeStepLog", 1).setValue("IncrementIntervalForHistory", 1)
	set loadcase = nothing
end sub

'Set placing temperature
sub set_placing_temperature(name, temp_value)
	set attr = database.createLoadingPrescribedTemperature(name)
	call attr.setType("Total")
	call attr.setTemperature("PHI", temp_value)
	call attr.setDlgUseHumidity(false)
	set attr = nothing
End Sub

'Set thermal loading 
sub set_thermal_loading(name, ambient_temperature, convection_heat)
	set attr = database.createLoadingEnvironmental(name)
	call attr.setEnvironmental()
	call attr.addRow(ambient_temperature, convection_heat, 0.0, 0.0, false, 0.0, 0.0, false)
	set attr = nothing
end sub

