#Region
#AutoIt3Wrapper_UseX64=y
#EndRegion

#include "Libs\autoit-opencv-com\udf\opencv_udf_utils.au3"
#include <GDIPlus.au3>
#include <GUIConstantsEx.au3>
#include <ScreenCapture.au3>

; Assume the game window size is 1264x712, not the client area size.
;   The size is it because my template images are captured on this size.
; This window size is adjusted by SmartSystemMenu. Resize to 1280x720.
;   ShareX can capture the game window in 1264x712.
; The function `ImageSearch` has a parameter relating to this size.

DllCall("user32.dll", "bool", "SetProcessDPIAware")
Local $arrDPIs = DllCall("user32.dll", "uint", "GetDpiForSystem") ; Windows 10+
Local $iWinScale = $arrDPIs[0] / 96 ; DPI 96 is 100%

_OpenCV_Open("Libs\opencv\build\x64\vc16\bin\opencv_world4120.dll", "Libs\autoit-opencv-com\autoit_opencv_com4120.dll")
_GDIPlus_Startup()
OnAutoItExitRegister("_OnAutoItExit")

Global $sGameWinTitle = "マブラヴ"
Global $sGameResDir = @ScriptDir & "\Games\MuvLuv\"
Global $sScriptLog = @ScriptDir & "\Game_MuvLuv.log"
Global $iLoopTimer = 500

Global $bMazeFarmingOn = False
Global $bWriteLogOn = False
Global $bRunning = False
Global $bPausing = False
Global $iPausingTimer = 0
Global $iPausingMax = $iLoopTimer
Global $bSingleRunning = False

Global $cv = _OpenCV_get()
If Not IsObj($cv) Then
    MsgBox(0, "Error", "Failed to get OpenCV COM object.")
    Exit
EndIf

; The font and size.
Local $sGUIFontName = "Segoe UI"
Local $iGUIFontSize = 10
Local $iGUIWidth = Int(255 * $iWinScale)
Local $iGUIHeight = Int(255 * $iWinScale)
GUICreate("MuvLuv Auto", $iGUIWidth, $iGUIHeight)

Local $iBtnSizeW = Int(100 * $iWinScale)
Local $iBtnSizeH = Int(40 * $iWinScale)
Local $iBtnPosX = Int(($iGUIWidth - $iBtnSizeW) / 2)
Local $iElementYStart = Int(10 * $iWinScale)
Local $iElementYGap = Int(5 * $iWinScale)
Local $btnStart = GUICtrlCreateButton("Start", $iBtnPosX, $iElementYStart, $iBtnSizeW, $iBtnSizeH)
GUICtrlSetFont($btnStart, $iGUIFontSize, $FW_NORMAL, 0, $sGUIFontName)

Local $iLblStatusPadTop = 3
Local $iLblStatusSizeW = Int(120 * $iWinScale)
Local $iLblStatusSizeH = Int(25 * $iWinScale) - $iLblStatusPadTop
Local $iLblStatusPosX = Int(($iGUIWidth - $iLblStatusSizeW) / 2)
Local $iLblStatusPosY = $iElementYStart + $iBtnSizeH + $iElementYGap * 2
Local $lblStatusPad = GUICtrlCreateLabel("", $iLblStatusPosX, $iLblStatusPosY, $iLblStatusSizeW, $iLblStatusPadTop)
GUICtrlSetBkColor($lblStatusPad, 0x000000)
; Initial string length needs attention.
Local $lblStatus = GUICtrlCreateLabel("  Status: Idle    ", $iLblStatusPosX, $iLblStatusPosY + $iLblStatusPadTop, $iLblStatusSizeW, $iLblStatusSizeH)
GUICtrlSetBkColor($lblStatus, 0x000000)
GUICtrlSetColor($lblStatus, 0xFFFFFF)
GUICtrlSetFont($lblStatus, $iGUIFontSize, $FW_NORMAL, 0, $sGUIFontName)

Local $iLblTipsSizeW = Int(235 * $iWinScale)
Local $iLblTipsSizeH = Int(20 * $iWinScale)
Local $iLblTipsPosX = Int(($iGUIWidth - $iLblTipsSizeW) / 2)
Local $iLblTipsStartY = $iLblStatusPosY + $iLblStatusSizeH + $iElementYGap * 2
Local $lblTip1 = GUICtrlCreateLabel("Tip1: Press Esc to stop looping.", $iLblTipsPosX, $iLblTipsStartY, $iLblTipsSizeW, $iLblTipsSizeH)
GUICtrlSetFont($lblTip1, $iGUIFontSize, $FW_NORMAL, 0, $sGUIFontName)
Local $lblTip2 = GUICtrlCreateLabel("Tip2: Keep an eye on the game.", $iLblTipsPosX, $iLblTipsStartY + $iLblTipsSizeH + $iElementYGap, $iLblTipsSizeW, $iLblTipsSizeH)
GUICtrlSetFont($lblTip2, $iGUIFontSize, $FW_NORMAL, 0, $sGUIFontName)
Local $lblTip3 = GUICtrlCreateLabel("Tip3: 1280x720 by SmartSystemMenu.", $iLblTipsPosX, $iLblTipsStartY + 2 * ($iLblTipsSizeH + $iElementYGap), $iLblTipsSizeW, $iLblTipsSizeH)
GUICtrlSetFont($lblTip3, $iGUIFontSize, $FW_NORMAL, 0, $sGUIFontName)

Local $iChkDebugSizeW = Int(100 * $iWinScale)
Local $iChkDebugSizeH = Int(20 * $iWinScale)
Local $iChkDebugPosX = Int(($iGUIWidth - $iChkDebugSizeW) / 2)
Local $iChkDebugPosY = $iGUIHeight - Int(25 * $iWinScale)
Local $chkDebug = GUICtrlCreateCheckbox("Enable log", $iChkDebugPosX, $iChkDebugPosY, $iChkDebugSizeW, $iChkDebugSizeH)
GUICtrlSetFont($chkDebug, $iGUIFontSize, $FW_NORMAL, 0, $sGUIFontName)

Local $iChkMazeFarmingSizeW = Int(150 * $iWinScale)
Local $iChkMazeFarmingSizeH = Int(20 * $iWinScale)
Local $iChkMazeFarmingPosX = Int(($iGUIWidth - $iChkMazeFarmingSizeW) / 2)
Local $iChkMazeFarmingPosY = $iChkDebugPosY - Int(25 * $iWinScale)
Local $chkMazeFarming = GUICtrlCreateCheckbox("Enable Maze Farming", $iChkMazeFarmingPosX, $iChkMazeFarmingPosY, $iChkMazeFarmingSizeW, $iChkMazeFarmingSizeH)
GUICtrlSetFont($chkMazeFarming, $iGUIFontSize, $FW_NORMAL, 0, $sGUIFontName)

; GUI Start
GUISetState(@SW_SHOW)
HotKeySet("{ESC}", "ActionStop")
While True
    Switch GUIGetMsg()
        ; When click close button
        Case $GUI_EVENT_CLOSE
            Exit
        Case $btnStart
            If $bRunning Then
                ActionStop()
            Else
                ActionStart()
            EndIf
        ; The check boxes
        Case $chkDebug
            If BitAND(GUICtrlRead($chkDebug), $GUI_CHECKED) = $GUI_CHECKED Then
                $bWriteLogOn = True
            Else
                $bWriteLogOn = False
            EndIf
        Case $chkMazeFarming
            If BitAND(GUICtrlRead($chkDebug), $GUI_CHECKED) = $GUI_CHECKED Then
                $bMazeFarmingOn = True
            Else
                $bMazeFarmingOn = False
            EndIf
    EndSwitch
WEnd

; Functions
Func ResetPausingState()
    $bPausing = False
    $iPausingTimer = 0
    $iPausingMax = $iLoopTimer
EndFunc

Func ActionStart()
    GUICtrlSetData($btnStart, "Stop")
    GUICtrlSetData($lblStatus, "  Status: Running ")
    GUICtrlSetColor($lblStatus, 0x00FF00)
    $bRunning = True
    AdlibRegister("AutoClick", $iLoopTimer)
EndFunc

Func ActionStop()
    GUICtrlSetData($btnStart, "Start")
    GUICtrlSetData($lblStatus, "  Status: Idle    ")
    GUICtrlSetColor($lblStatus, 0xFFFFFF)
    $bRunning = False
    ResetPausingState()
    AdlibUnRegister("AutoClick")
EndFunc

Func ActionContinue()
    If Not $bRunning Then
        Return
    EndIf
    GUICtrlSetData($lblStatus, "  Status: Running ")
    GUICtrlSetColor($lblStatus, 0x00FF00)
    ResetPausingState()
    AdlibRegister("AutoClick", $iLoopTimer)
EndFunc

Func ActionPause($iMilliSeconds)
    GUICtrlSetData($lblStatus, "  Status: Waiting ")
    GUICtrlSetColor($lblStatus, 0xFFD966)
    $bPausing = True
    if $iMilliSeconds > 0 Then
        $iPausingMax = $iMilliSeconds
    EndIf
EndFunc

; Image Search Functions.
; #FUNCTION# ==========================================================================================================
; Name ..........: ImageSearch
; Description ...: Find image in the game window or subarea relative to the game.
; Syntax ........: ImageSearch($sImageFile[, $fThreshold = 0.8[, $arrSubArea = Default[, $iBaseHeight = 712]]])
; Parameters ....: $sImageFile      - Image path.
;                  $fThreshold      - [optional] The threshold. Default is 0.8
;                  $arrSubArea      - [optional] The sub area [x, y, w, h] relative to the game window. Default is the
;                                                whole game window.
;                  $iBaseHeight     - [optional] The base game window height where you capture the template images. So
;                                                the  captured images should be capture in the same window size. If the
;                                                running game window size is different, the template image will be
;                                                resized proportionally to  match the window size. Though it's better
;                                                to keep your game window size consistent.
; Return values .: Array of area relative to the game window if find. Otherwise just silent.
; Remarks .......:
;   Assuming using SmartSystemMenu to resize to 1280x720 that give the game window size 1264x712 reducing the border
;   shadow size I think.
; =====================================================================================================================
Func ImageSearch($sImageFile, $fThreshold = 0.8, $arrSubArea = Default, $iBaseHeight = 712)
    Local $imgTempl = _OpenCV_imread_and_check($sImageFile)

    Local $arrArea = WinGetPos($sGameWinTitle)
    Local $iActualHeight = $arrArea[3]
    If $arrSubArea <> Default Then
        $arrArea[0] += $arrSubArea[0]
        $arrArea[1] += $arrSubArea[1]
        $arrArea[2] = $arrSubArea[2]
        $arrArea[3] = $arrSubArea[3]
    EndIf
    Local $imgScreen = _OpenCV_GetDesktopScreenMat($arrArea)

    If $imgTempl.empty() Or $imgScreen.empty() Then
        Return False
    EndIf

    If $iActualHeight <> $iBaseHeight Then
        Local $fProportion = $iBaseHeight / $iActualHeight
        Local $iAdjWidth = int($imgTempl.width * $fProportion)
        Local $iAdjHeight = int($imgTempl.height * $fProportion)
        $imgTempl = $cv.resize($imgTempl, _OpenCV_Size($iAdjWidth, $iAdjHeight))
    EndIf

    Local $iN = 1
    Local $imgTemplOpt = $cv.cvtColor($imgTempl, 6)
    Local $imgScreenOpt = $cv.cvtColor($imgScreen, 6)
    If $imgScreen.width > $imgTempl.width And $imgScreen.height > $imgTempl.height Then
        $iN = 2
        $imgTemplOpt = $cv.resize($imgTemplOpt, _OpenCV_Size($imgTempl.width / $iN, $imgTempl.height / $iN))
        $imgScreenOpt = $cv.resize($imgScreenOpt, _OpenCV_Size($imgScreen.width / $iN, $imgScreen.height / $iN))
    EndIf
    Local $matchResults = _OpenCV_FindTemplate($imgScreenOpt, $imgTemplOpt, $fThreshold)  ; Covariant Matrix Normal
    If IsArray($matchResults) And UBound($matchResults) > 0 Then
        Local $arrRect = [$matchResults[0][0] * $iN, $matchResults[0][1] * $iN, $imgTempl.width, $imgTempl.height]
        Return SetError(0, 0, $arrRect)
    Else
        Return SetError(0, 0, False)
    EndIf
EndFunc

; When no shifts, default to click the center of the image. The shifts are relative to the center.
Func ClickRelateWindow($arrArea, $arrRect, $iShiftX = 0, $iShiftY = 0, $bBgClick = False)
    If $bBgClick Then
        ; Only when this message is accepted, but mostly can't because it's cheat apparently.
        Local $arrClientPos = WinGetClientSize($sGameWinTitle)
        Local $x = $arrArea[0] - $arrClientPos[0] + $arrRect[0] + Int($arrRect[2] / 2)
        Local $y = $arrArea[1] - $arrClientPos[1] + $arrRect[1] + Int($arrRect[3] / 2)
        ControlClick($sGameWinTitle, "", "", "left", 1, $x + $iShiftX, $y + $iShiftY)
    Else
        Local $x = $arrArea[0] + $arrRect[0] + Int($arrRect[2] / 2)
        Local $y = $arrArea[1] + $arrRect[1] + Int($arrRect[3] / 2)
        MouseClick("left", $x + $iShiftX, $y + $iShiftY, 1, 0)
    EndIf
EndFunc

; CD: If the image would still be presented for a while after being clicked,
; then if in the next loop the same image is the
; "next" detected, skip it for 1 as the CD unit.
Func ClickImage($sImageFile, $fThreshold = 0.85, $iShiftX = 0, $iShiftY = 0, $bCDOn = False, $iCDMax = 2, $arrSubArea = Default)
    Static $sCDImageFile = ""
    Static $iCD = 0

    Local $arrRect = ImageSearch($sImageFile, $fThreshold, $arrSubArea)
    Local $arrArea = WinGetPos($sGameWinTitle)
    If $arrSubArea <> Default Then
        $arrArea[0] += $arrSubArea[0]
        $arrArea[1] += $arrSubArea[1]
        $arrArea[2] = $arrSubArea[2]
        $arrArea[3] = $arrSubArea[3]
    EndIf

    If IsArray($arrRect) Then
        If $bCDOn And $sCDImageFile = $sImageFile Then
            $iCD += 1
            If $iCD >= $iCDMax Then
                $iCD = 0
                ClickRelateWindow($arrArea, $arrRect, $iShiftX, $iShiftY)
                Return SetError(0, 0, True)
            EndIf
        Else
            If $iCD <> 0 Then $iCD = 0
            ClickRelateWindow($arrArea, $arrRect, $iShiftX, $iShiftY)
            $sCDImageFile = $sImageFile
            Return SetError(0, 0, True)
        EndIf
    Else
        Return SetError(1, 0, False)
    EndIf
EndFunc

; Maze Shop Functions
Func MazeShopBuying()
    Local $fDefaultThreshold = 0.80
    Local $fHigherThreshold = 0.90
    Local $bDefaultCDOn = False
    Local $iDefaultCDFactor = 2

    Local $areaCurrency = [1060, 70, 160, 45]
    Local $areaBuy1 = [490, 215, 200, 55]
    Local $areaBuy2 = [975, 215, 200, 55]
    Local $areaBuy3 = [490, 340, 200, 55]
    Local $areaBuy4 = [975, 340, 200, 55]
    Local $areaBuy5 = [490, 465, 200, 55]
    ; Local $areaBuy6 = [975, 465, 200, 55]

    Local $iDelayAnimate = 1500
    Local $iDelayReaction = 250

    Sleep($iDelayReaction)

    If Not $bRunning Then
        Return True
    EndIf

    While ClickImage($sGameResDir & "MazeShop\BuyA.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaBuy1) Or _
          ClickImage($sGameResDir & "MazeShop\BuyA.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaBuy2) Or _
          ClickImage($sGameResDir & "MazeShop\BuyA.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaBuy3) Or _
          ClickImage($sGameResDir & "MazeShop\BuyA.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaBuy4) Or _
          ClickImage($sGameResDir & "MazeShop\BuyA.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaBuy5)
        Sleep($iDelayAnimate)
    WEnd

    If Not $bRunning Then
        Return True
    EndIf

    If ClickImage($sGameResDir & "MazeShop\BuyB.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaBuy1) Or _
       ClickImage($sGameResDir & "MazeShop\BuyB.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaBuy2) Or _
       ClickImage($sGameResDir & "MazeShop\BuyB.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaBuy3) Or _
       ClickImage($sGameResDir & "MazeShop\BuyB.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaBuy4) Or _
       ClickImage($sGameResDir & "MazeShop\BuyB.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaBuy5) Then
        Sleep($iDelayReaction)
    EndIf

    If Not $bRunning Then
        Return True
    EndIf

    If ClickImage($sGameResDir & "Maze_Shop.png", $fHigherThreshold, -50, 570, $bDefaultCDOn, $iDefaultCDFactor, $areaCurrency) Then
        Return True
    EndIf
    Return False
EndFunc

Func MazeShopBuyingTypes()
    Local $fDefaultThreshold = 0.85
    Local $bDefaultCDOn = False
    Local $iDefaultCDFactor = 2

    Local $areaType1 = [195, 135, 135, 35]
    Local $areaType2 = [340, 135, 135, 35]
    Local $areaType3 = [485, 135, 135, 35]

    If MazeShopBuying() Then
        Return True
    EndIf
    ClickImage($sGameResDir & "MazeShop\Type_EN.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaType2)
    If MazeShopBuying() Then
        Return True
    EndIf
    ClickImage($sGameResDir & "MazeShop\Type_Agile.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaType3)
    If MazeShopBuying() Then
        Return True
    EndIf
    ClickImage($sGameResDir & "MazeShop\Type_Physical.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaType1)
    Return False
EndFunc

Func MazeShopFarming()
    Local $fDefaultThreshold = 0.85
    Local $fLowerThreshold = 0.80
    Local $bDefaultCDOn = False
    Local $iDefaultCDFactor = 2

    Local $areaBatchBtn = [1065, 135, 150, 45]
    ClickImage($sGameResDir & "MazeShop\Daily_Batch.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaBatchBtn)

    Local $areaTypeEquip = [10, 295, 135, 75]
    ClickImage($sGameResDir & "MazeShop\Cate_TypeEquip.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaTypeEquip)
    If MazeShopBuyingTypes() Then
        Return
    EndIf

    Local $areaExcavate = [10, 375, 135, 75]
    ClickImage($sGameResDir & "MazeShop\Cate_Excavate.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaExcavate)
    If MazeShopBuying() Then
        Return
    EndIf

    Local $areaArtifact = [10, 455, 135, 75]
    ClickImage($sGameResDir & "MazeShop\Cate_Artifact.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaArtifact)
    If MazeShopBuyingTypes() Then
        Return
    EndIf

    Local $areaAbortA = [1020, 635, 195, 45]
    ClickImage($sGameResDir & "MazeShop\AbortA.png", $fLowerThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaAbortA)

    Local $areaAbortB = [660, 525, 160, 45]
    While $bRunning And Not ClickImage($sGameResDir & "MazeShop\AbortB.png", $fLowerThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaAbortB)
        Sleep(500)
    WEnd
EndFunc

Func MazeNetworkErrored()
    Local $fDefaultThreshold = 0.85
    Local $bDefaultCDOn = False
    Local $iDefaultCDFactor = 2

    Local $iSleepNetwork = 2000
    Local $iSleepSwitch = 1000
    Sleep($iSleepNetwork)
    Local $areaHomeQuest = [705, 655, 105, 40]
    While $bRunning And Not ClickImage($sGameResDir & "Home_Quest.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaHomeQuest)
        Sleep($iSleepNetwork)
    WEnd
    Sleep($iSleepSwitch)
    Local $areaHomeQuestMaze = [985, 315, 180, 50]
    While $bRunning And Not ClickImage($sGameResDir & "HomeQuest_Maze.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaHomeQuestMaze)
        Sleep($iSleepSwitch)
    Wend
EndFunc

; Log Function
Func WriteLog($msg)
    Local $hFile = FileOpen($sScriptLog, $FO_APPEND + $FO_CREATEPATH)
    If $hFile = -1 Then Return SetError(1, 0, 0)

    FileWriteLine($hFile, _
        @YEAR & "-" & @MON & "-" & @MDAY & " " & _
        @HOUR & ":" & @MIN & ":" & @SEC & " - " & $msg)

    FileClose($hFile)
EndFunc

; Looped Function
Func AutoClick()
    If Not $bRunning Or $bSingleRunning Then
        Return
    EndIf

    If $bPausing Then
        $iPausingTimer += $iLoopTimer
        If $iPausingTimer > $iPausingMax Then
            ActionContinue()
        Else
            Return
        EndIf
    EndIf

    If WinExists($sGameWinTitle) Then
        If $bWriteLogOn Then
            Local $hTimer = TimerInit()
        EndIf

        WinActivate($sGameWinTitle)

        Local $fLowerThreshold = 0.70
        Local $fDefaultThreshold = 0.80
        Local $fHigherThreshold = 0.90
        Local $bDefaultCDOn = False
        Local $iDefaultCDFactor = 2

        Local $arrSubAreaLoading = [585, 335, 95, 75]
        If IsArray(ImageSearch($sGameResDir & "Game_Loading.png", $fDefaultThreshold, $arrSubAreaLoading)) Then
            ActionPause(1500)
            Return
        EndIf

        Local $arrSubAreaCorRB = [781, 493, 483, 219]
        If ClickImage($sGameResDir & "Maze_Ready.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRB) Or _
           ClickImage($sGameResDir & "Maze_Route.png", $fLowerThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRB) Or _
           ClickImage($sGameResDir & "Quest_Enter.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRB) Then
            ActionPause(2500)
            Return
        EndIf
        ClickImage($sGameResDir & "Maze_Enter.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRB)
        ClickImage($sGameResDir & "Maze_DeHelper.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRB)
        ClickImage($sGameResDir & "Sim_Enter.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRB)
        ClickImage($sGameResDir & "Com_Battle.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRB)
        ClickImage($sGameResDir & "Com_Continue.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRB)
        ClickImage($sGameResDir & "Quest_Scene.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRB)

        Local $arrSubAreaCorRU = [740, 36, 524, 93]
        If ClickImage($sGameResDir & "Game_Menu.png", $fDefaultThreshold, -560, 370, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRU) Then
            If $bMazeFarmingOn Then
                $bSingleRunning = True
                MazeNetworkErrored()
                $bSingleRunning = False
            EndIf
            Return
        EndIf
        ClickImage($sGameResDir & "Com_SkipBattle.png", $fLowerThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRU)
        ClickImage($sGameResDir & "Com_SkipLight.png", $fLowerThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRU)
        ClickImage($sGameResDir & "Maze_Shop.png", $fHigherThreshold, -50, 570, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorRU)

        Local $arrSubAreaCorLU = [84, 52, 120, 43]
        ClickImage($sGameResDir & "Gacha_Title.png", $fDefaultThreshold, -90, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCorLU)

        Local $arrSubAreaCtrDw = [310, 385, 645, 205]
        ClickImage($sGameResDir & "Game_ErrorClose.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCtrDw)
        ClickImage($sGameResDir & "Game_ErrorTitle.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaCtrDw)

        Local $arrSubAreaSetC1 = [523, 187, 217, 49]
        ClickImage($sGameResDir & "Com_FlashSale.png", $fDefaultThreshold, 555, -135, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaSetC1)

        Local $arrSubAreaSetC2 = [499, 162, 272, 49]
        If ClickImage($sGameResDir & "Com_FlashRelay.png", $fDefaultThreshold, 230, 110, False, $iDefaultCDFactor, $arrSubAreaSetC2) Then
            ClickImage($sGameResDir & "Com_FlashRelay.png", $fDefaultThreshold, 555, -110, False, $iDefaultCDFactor, $arrSubAreaSetC2)
        EndIF

        Local $arrSubAreaSetM1 = [543, 131, 185, 68]
        ClickImage($sGameResDir & "Maze_SelRelic.png", $fDefaultThreshold, 0, 150, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaSetM1)

        Local $arrSubAreaSetM2 = [385, 238, 203, 45]
        ClickImage($sGameResDir & "Maze_SelTypeA.png", $fLowerThreshold, 270, 145, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaSetM2)
        ClickImage($sGameResDir & "Maze_SelTypeB.png", $fLowerThreshold, 270, 145, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaSetM2)

        Local $arrSubAreaSetM3 = [1007, 254, 206, 44]
        ClickImage($sGameResDir & "Maze_SelHelperA.png", $fLowerThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaSetM3)
        ClickImage($sGameResDir & "Maze_SelHelperB.png", $fLowerThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaSetM3)

        Local $arrSubAreaSetM4 = [67, 386, 229, 78]
        ClickImage($sGameResDir & "Maze_Trans.png", $fDefaultThreshold, 960, 240, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaSetM4)

        If IsArray(ImageSearch($sGameResDir & "Com_SkipLocked.png", $fDefaultThreshold, $arrSubAreaCorRU)) Then
            ActionPause(4500)
            Return
        EndIf

        If IsArray(ImageSearch($sGameResDir & "Com_TryAgain.png", $fDefaultThreshold, $arrSubAreaCorRB)) Or _
           IsArray(ImageSearch($sGameResDir & "Com_Limited.png", $fDefaultThreshold, $arrSubAreaCorRB)) Or _
           IsArray(ImageSearch($sGameResDir & "Quest_Clear.png", $fDefaultThreshold, $arrSubAreaCorRB)) Or _
           IsArray(ImageSearch($sGameResDir & "ADV_Menu.png", $fDefaultThreshold, $arrSubAreaCorRU)) Then
            ActionStop()
        EndIf

        Local $iReactionTimer = 500
        Local $arrSubAreaSetM5 = [630, 135, 135, 35]
        If ClickImage($sGameResDir & "MazeShop\Daily_Unit.png", $fDefaultThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $arrSubAreaSetM5) Then
            $bSingleRunning = True
            Sleep($iReactionTimer)
            If Not $bRunning Then Return
            Local $arrSubAreaSetM6 = [315, 580, 70, 30]
            If IsArray(ImageSearch($sGameResDir & "MazeShop\Daily_Clear.png", $fHigherThreshold, $arrSubAreaSetM6)) Then
                If $bMazeFarmingOn Then
                    MazeShopFarming()
                Else
                    Local $areaAbortA = [1020, 635, 195, 45]
                    ClickImage($sGameResDir & "MazeShop\AbortA.png", $fLowerThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaAbortA)
                    Local $areaAbortB = [660, 525, 160, 45]
                    While $bRunning And Not ClickImage($sGameResDir & "MazeShop\AbortB.png", $fLowerThreshold, 0, 0, $bDefaultCDOn, $iDefaultCDFactor, $areaAbortB)
                        Sleep($iReactionTimer)
                    WEnd
                EndIf
            EndIf
            $bSingleRunning = False
        EndIf

        If $bWriteLogOn Then
            Local $fElapsed = TimerDiff($hTimer)
            WriteLog("AutoClick: " & $fElapsed & " ms")
        EndIf
    Else
        MsgBox(0, "Error", "Game window not found.")
        ActionStop()
    EndIf
EndFunc

; Internal Handling
Func _OnAutoItExit()
    _GDIPlus_Shutdown()
    _OpenCV_Close()
EndFunc
