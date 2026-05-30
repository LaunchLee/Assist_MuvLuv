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

Global $sGameWinTitle   = "マブラヴ"
Global $sGameResDir     = @ScriptDir & "\Games\MuvLuv\"
Global $sScriptLog      = @ScriptDir & "\Game_MuvLuv.log"
Global $iLoopTimer      = 500

Global $bMazeFarmingOn  = False
Global $bWriteLogOn     = False
Global $bRunning        = False
Global $bPausing        = False
Global $iPausingTimer   = 0
Global $iPausingMax     = $iLoopTimer
Global $bSingleRunning  = False

Global $cv = _OpenCV_get()
If Not IsObj($cv) Then
    MsgBox(16, "Error", "Failed to get OpenCV COM object.")
    Exit
EndIf

; The font and size.
Local $sFont = "Segoe UI"
Local $iFontSize = 10
Local $iGUIWidth = Int(255 * $iWinScale), $iGUIHeight = Int(255 * $iWinScale)

GUICreate("MuvLuv Auto", $iGUIWidth, $iGUIHeight)
GUISetFont($iFontSize, $FW_NORMAL, 0, $sFont)

Local $iBtnW = Int(100 * $iWinScale), $iBtnH = Int(40 * $iWinScale)
Local $btnStart = GUICtrlCreateButton("Start", Int(($iGUIWidth - $iBtnW) / 2), Int(10 * $iWinScale), $iBtnW, $iBtnH)

Local $iPadTop = 3
Local $iStatusW = Int(120 * $iWinScale), $iStatusH = Int(25 * $iWinScale) - $iPadTop
Local $iStatusX = Int(($iGUIWidth - $iStatusW) / 2)
Local $iStatusY = Int(10 * $iWinScale) + $iBtnH + Int(10 * $iWinScale) ; 合并 Gap 运算

Local $lblStatusPad = GUICtrlCreateLabel("", $iStatusX, $iStatusY, $iStatusW, $iPadTop)
GUICtrlSetBkColor($lblStatusPad, 0x000000)
; Initial string length needs attention.
Global $lblStatus = GUICtrlCreateLabel("  Status: Idle    ", $iStatusX, $iStatusY + $iPadTop, $iStatusW, $iStatusH)
GUICtrlSetBkColor($lblStatus, 0x000000)
GUICtrlSetColor($lblStatus, 0xFFFFFF)

Local $iTipsW = Int(235 * $iWinScale), $iTipsH = Int(20 * $iWinScale)
Local $iTipsX = Int(($iGUIWidth - $iTipsW) / 2)
Local $iTipsY = $iStatusY + $iStatusH + Int(10 * $iWinScale)
Local $iTipsGap = $iTipsH + Int(5 * $iWinScale)

Local $aTipsText[3] = [ _
    "Tip1: Press Esc to stop looping.", _
    "Tip2: Keep an eye on the game.", _
    "Tip3: 1280x720 by SmartSystemMenu." _
]
For $i = 0 To 2
    GUICtrlCreateLabel($aTipsText[$i], $iTipsX, $iTipsY + ($i * $iTipsGap), $iTipsW, $iTipsH)
Next

Local $iChkDebugW = Int(100 * $iWinScale), $iChkDebugH = Int(20 * $iWinScale)
Local $iChkDebugY = $iGUIHeight - Int(25 * $iWinScale)
Local $chkDebug = GUICtrlCreateCheckbox("Enable log", Int(($iGUIWidth - $iChkDebugW) / 2), $iChkDebugY, $iChkDebugW, $iChkDebugH)

Local $iChkMazeW = Int(150 * $iWinScale), $iChkMazeH = Int(20 * $iWinScale)
Local $iChkMazeY = $iChkDebugY - Int(25 * $iWinScale)
Local $chkMazeFarming = GUICtrlCreateCheckbox("Enable Maze Farming", Int(($iGUIWidth - $iChkMazeW) / 2), $iChkMazeY, $iChkMazeW, $iChkMazeH)

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
            $bWriteLogOn = (GUICtrlRead($chkDebug) = $GUI_CHECKED)

        Case $chkMazeFarming
            $bMazeFarmingOn = (GUICtrlRead($chkMazeFarming) = $GUI_CHECKED)
    EndSwitch
WEnd

; Functions
Func ResetPausingState()
    $bPausing = False
    $iPausingTimer = 0
    $iPausingMax = 0
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
    If Not $bRunning Then Return
    GUICtrlSetData($lblStatus, "  Status: Running ")
    GUICtrlSetColor($lblStatus, 0x00FF00)
    ResetPausingState()
EndFunc

Func ActionPause($iMilliSeconds)
    GUICtrlSetData($lblStatus, "  Status: Waiting ")
    GUICtrlSetColor($lblStatus, 0xFFD966)
    $iPausingTimer = 0
    $iPausingMax = $iMilliSeconds
    $bPausing = True
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
    ; Gray
    Local $imgTemplOpt = $cv.cvtColor($imgTempl, 6)
    Local $imgScreenOpt = $cv.cvtColor($imgScreen, 6)
    Local $iTotalCosts = $imgScreen.width * $imgScreen.height * $imgTempl.width * $imgTempl.height
    If $iTotalCosts > 147456000000 Then
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
    Local $iCenterX = $arrRect[0] + Int($arrRect[2] / 2) + $iShiftX
    Local $iCenterY = $arrRect[1] + Int($arrRect[3] / 2) + $iShiftY
    If $bBgClick Then
        ; Only when this message is accepted, but mostly can't because it's cheat apparently.
        ControlClick($sGameWinTitle, "", "", "left", 1, $iCenterX, $iCenterY)
    Else
        MouseClick("left", $arrArea[0] + $iCenterX, $arrArea[1] + $iCenterY, 1, 0)
    EndIf
EndFunc

; CD: If the image would still be presented for a while after being clicked,
; then if in the next loop the same image is the
; "next" detected, skip it for 1 as the CD unit.
Func ClickImage($sImageFile, $fThreshold = 0.85, $iShiftX = 0, $iShiftY = 0, $bCDOn = False, $iCDMax = 2, $arrSubArea = Default)
    Static $sCDImageFile = ""
    Static $iCD = 0

    Local $arrRect = ImageSearch($sImageFile, $fThreshold, $arrSubArea)
    If Not IsArray($arrRect) Then
        Return SetError(1, 0, False)
    EndIf

    If $bCDOn And $sCDImageFile = $sImageFile Then
        $iCD += 1
        If $iCD < $iCDMax Then
            Return SetError(0, 0, True)
        Endif
        $iCD = 0
    Else
        $iCD = 0
        $sCDImageFile = $sImageFile
    EndIf

    Local $arrArea = WinGetPos($sGameWinTitle)
    If $arrSubArea <> Default Then
        $arrRect[0] += $arrSubArea[0]
        $arrRect[1] += $arrSubArea[1]
    EndIf

    ClickRelateWindow($arrArea, $arrRect, $iShiftX, $iShiftY)
    Return SetError(0, 0, True)
EndFunc

; Maze Shop Functions
Func MazeShopBuying()
    Local $fDefaultThreshold = 0.80, $fHigherThreshold = 0.90
    Local $bDefaultCDOn = False, $iDefaultCDFactor = 2
    Local $iDelayAnimate = 1500, $iDelayReaction = 150

    Sleep($iDelayReaction)
    If Not $bRunning Then Return True

    While _ScanAndClickBuy("BuyUpgrade.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor)
        Sleep($iDelayAnimate)
        If Not $bRunning Then Return True
    WEnd

    _MazeShopScroll("down")
    Sleep($iDelayReaction)

    While _ScanAndClickBuy("BuyUpgrade.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor)
        Sleep($iDelayAnimate)
        If Not $bRunning Then Return True
    WEnd

    _MazeShopScroll("up")
    Sleep($iDelayReaction)

    Local $bBoughtB = False
    If _ScanAndClickBuy("BuyInvest.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor) Then
        $bBoughtB = True
        Sleep($iDelayReaction)
    EndIf

    _MazeShopScroll("down")
    Sleep($iDelayReaction)

    If _ScanAndClickBuy("BuyInvest.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor) Then
        $bBoughtB = True
        Sleep($iDelayReaction)
    EndIf

    _MazeShopScroll("up")
    Sleep($iDelayReaction)

    If Not $bRunning Then Return True

    Local $areaCurrency = [1060, 70, 160, 45]
    If ClickImage($sGameResDir & "Maze_Shop.png", $fHigherThreshold, -50, 570, $bDefaultCDOn, $iDefaultCDFactor, $areaCurrency) Then
        Return True
    EndIf
    Return $bBoughtB
EndFunc

Func _ScanAndClickBuy($sImageName, $fThreshold, $bCDOn, $iCDFactor)
    Local $arrMegaShopViewport = [450, 145, 750, 450]
    Local $sFullImagePath = $sGameResDir & "MazeShop\" & $sImageName

    If ClickImage($sFullImagePath, $fThreshold, 0, 0, $bCDOn, $iCDFactor, $arrMegaShopViewport) Then
        Return True
    EndIf

    Return False
EndFunc

Func _MazeShopScroll($sDirection = "down")
    If Not $bRunning Then Return

    Local $arrArea = WinGetPos($sGameWinTitle)
    If @error Then Return

    Local $iTargetX = $arrArea[0] + Int($arrArea[2] * 0.577)
    Local $iTargetY = $arrArea[1] + Int($arrArea[3] * 0.477)

    MouseMove($iTargetX, $iTargetY, 0)

    If $sDirection = "down" Then
        MouseWheel("down", 5)
    Else
        MouseWheel("up", 5)
    EndIf
EndFunc

Func MazeShopBuyingTypes()
    Local $fDefaultThreshold = 0.85, $bCD = False, $iCDFactor = 2
    Local $aTypes[3][5] = [ _
        ["Type_EN.png",       340, 135, 135, 35], _
        ["Type_Agile.png",    485, 135, 135, 35], _
        ["Type_Physical.png", 195, 135, 135, 35]  _
    ]

    If MazeShopBuying() Then Return True

    For $i = 0 To 2
        Local $arrSubArea = [$aTypes[$i][1], $aTypes[$i][2], $aTypes[$i][3], $aTypes[$i][4]]
        Local $sFullImagePath = $sGameResDir & "MazeShop\" & $aTypes[$i][0]
        ClickImage($sFullImagePath, $fDefaultThreshold, 0, 0, $bCD, $iCDFactor, $arrSubArea)
        If MazeShopBuying() Then Return True
    Next

    Return False
EndFunc

Func MazeShopFarming()
    Local $fDefault = 0.85, $fLow = 0.80, $bCD = False, $iCDFactor = 2, $iDelayReaction = 250

    Local $arrDailyBatchArea = [1065, 135, 150, 45]
    ClickImage($sGameResDir & "MazeShop\Daily_Batch.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrDailyBatchArea)
    Sleep($iDelayReaction)

    Local $aCates[3][5] = [ _
        ["Cate_TypeEquip.png", 10, 295, 135, 75], _
        ["Cate_Excavate.png",  10, 375, 135, 75], _
        ["Cate_Artifact.png",  10, 455, 135, 75]  _
    ]

    For $i = 0 To 2
        Local $arrSubArea = [$aCates[$i][1], $aCates[$i][2], $aCates[$i][3], $aCates[$i][4]]
        Local $sFullImagePath = $sGameResDir & "MazeShop\" & $aCates[$i][0]
        ClickImage($sFullImagePath, $fDefault, 0, 0, $bCD, $iCDFactor, $arrSubArea)
        Local $bStatus = ($i = 1) ? MazeShopBuying() : MazeShopBuyingTypes()
        If $bStatus Then Return
    Next

    _MazeShopAbort($fLow, $bCD, $iCDFactor)
EndFunc

Func _MazeShopAbort($fThreshold, $bCD, $iCDFactor)
    Local $areaAbortBtn = [1020, 635, 195, 45]
    ClickImage($sGameResDir & "MazeShop\AbortBtn.png", $fThreshold, 0, 0, $bCD, $iCDFactor, $areaAbortBtn)
    Local $areaAbortOK = [660, 525, 160, 45]
    While $bRunning And Not ClickImage($sGameResDir & "MazeShop\AbortOK.png", $fThreshold, 0, 0, $bCD, $iCDFactor, $areaAbortOK)
        Sleep(500)
    WEnd
EndFunc

Func MazeNetworkErrored()
    Local $fDefault = 0.85, $bCD = False, $iCDFactor = 2
    Local $iSleep = 2000
    Sleep($iSleep)

    Local $sHomeQuestPath = $sGameResDir & "Home_Quest.png"
    Local $areaHomeQuest = [705, 655, 105, 40]
    While $bRunning And Not ClickImage($sHomeQuestPath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeQuest)
        Sleep($iSleep)
    WEnd

    Sleep($iSleep)

    Local $sHomeMazePath = $sGameResDir & "HomeQuest_Maze.png"
    Local $areaHomeMaze = [985, 315, 180, 50]
    While $bRunning And Not ClickImage($sHomeMazePath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeMaze)
        Sleep($iSleep)
    WEnd

    Sleep($iSleep)

    Local $sHomeMazeEntryPath = $sGameResDir & "HomeQuest_MazeEntryA.png"
    Local $areaHomeMazeEntryA = [310, 510, 270, 90]
    ClickImage($sHomeMazeEntryPath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeMazeEntryA)
EndFunc

; Log Function
Func WriteLog($msg)
    Local $hFile = FileOpen($sScriptLog, $FO_APPEND + $FO_CREATEPATH)
    If $hFile = -1 Then Return SetError(1, 0, 0)

    FileWriteLine($hFile, StringFormat("%04d-%02d-%02d %02d:%02d:%02d - %s", @YEAR, @MON, @MDAY, @HOUR, @MIN, @SEC, $msg))
    FileClose($hFile)
EndFunc

; Looped Function
Func AutoClick()
    If Not $bRunning Or $bSingleRunning Then Return

    If $bPausing Then
        $iPausingTimer += $iLoopTimer
        If $iPausingTimer >= $iPausingMax Then
            ActionContinue()
        EndIf
        Return
    EndIf

    If Not WinExists($sGameWinTitle) Then
        MsgBox(16, "Error", "Game window not found.")
        ActionStop()
        Return
    EndIf

    Local $hTimer = $bWriteLogOn ? TimerInit() : 0
    WinActivate($sGameWinTitle)

    Local $fLow = 0.80, $fDefault = 0.85, $fHigh = 0.90
    Local $bCD = False, $iCDFactor = 2
    Local $iPopupDelay = 500

    Local $arrLoadingArea = [585, 335, 95, 75]
    If IsArray(ImageSearch($sGameResDir & "Game_Loading.png", $fDefault, $arrLoadingArea)) Then
        ActionPause(1500)
        Return
    EndIf

    Local $arrRB = [781, 493, 483, 219]
    If ClickImage($sGameResDir & "Maze_Ready.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrRB) Or _
       ClickImage($sGameResDir & "Maze_Route.png", $fLow - 0.05, 0, 0, $bCD, $iCDFactor, $arrRB) Or _
       ClickImage($sGameResDir & "Quest_Enter.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrRB) Then
        ActionPause(2500)
        Return
    EndIf

    Local $aSingleClicks[6] = ["Maze_Enter.png", "Maze_DeHelper.png", "Sim_Enter.png", "Com_Battle.png", "Com_Continue.png", "Quest_Scene.png"]
    For $img In $aSingleClicks
        ClickImage($sGameResDir & $img, $fDefault, 0, 0, $bCD, $iCDFactor, $arrRB)
    Next

    Local $arrRU = [740, 36, 524, 93]
    If ClickImage($sGameResDir & "Game_Menu.png", $fDefault, -560, 370, $bCD, $iCDFactor, $arrRU) Then
        If $bMazeFarmingOn Then
            $bSingleRunning = True
            MazeNetworkErrored()
            $bSingleRunning = False
        EndIf
        Return
    EndIf
    ClickImage($sGameResDir & "Com_SkipBattle.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrRU)
    ClickImage($sGameResDir & "Com_SkipLight.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrRU)
    ClickImage($sGameResDir & "Maze_Shop.png", $fHigh, -50, 570, $bCD, $iCDFactor, $arrRU)

    Local $arrGachaTitleArea = [84, 52, 120, 43]
    ClickImage($sGameResDir & "Gacha_Title.png", $fDefault, -90, 0, $bCD, $iCDFactor, $arrGachaTitleArea)

    Local $arrDw = [310, 385, 645, 205]
    ClickImage($sGameResDir & "Game_ErrorClose.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrDw)
    ClickImage($sGameResDir & "Game_ErrorTitle.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrDw)

    Local $arrFlashSaleArea = [523, 187, 217, 49]
    ClickImage($sGameResDir & "Com_FlashSale.png", $fDefault, 555, -135, $bCD, $iCDFactor, $arrFlashSaleArea)

    Local $arrC2 = [499, 162, 272, 49]
    If ClickImage($sGameResDir & "Com_FlashRelay.png", $fDefault, 230, 110, False, $iCDFactor, $arrC2) Then
        ClickImage($sGameResDir & "Com_FlashRelay.png", $fDefault, 555, -110, False, $iCDFactor, $arrC2)
    EndIf

    Local $arrM1 = [543, 131, 185, 68]
    ClickImage($sGameResDir & "Maze_SelRelic.png", $fDefault, 0, 150, $bCD, $iCDFactor, $arrM1)
    ClickImage($sGameResDir & "Maze_SelRelic200.png", $fDefault, 0, 150, $bCD, $iCDFactor, $arrM1)

    Local $arrM2 = [385, 238, 203, 45]
    ClickImage($sGameResDir & "Maze_SelTypeA.png", $fLow, 270, 145, $bCD, $iCDFactor, $arrM2)
    ClickImage($sGameResDir & "Maze_SelTypeB.png", $fLow, 270, 145, $bCD, $iCDFactor, $arrM2)
    ClickImage($sGameResDir & "Maze_SelTypeC.png", $fLow, 270, 145, $bCD, $iCDFactor, $arrM2)

    Local $arrM3 = [1007, 254, 206, 44]
    ClickImage($sGameResDir & "Maze_SelHelperA.png", $fHigh, 0, 0, $bCD, $iCDFactor, $arrM3)
    ClickImage($sGameResDir & "Maze_SelHelperB.png", $fHigh, 0, 0, $bCD, $iCDFactor, $arrM3)

    Local $arrTransArea = [67, 386, 229, 78]
    Local $arrEvOptsArea = [1128, 307, 100, 370]
    Local $arrNotCraftArea = [864, 626, 149, 39]
    Local $arrNotCraftOKArea = [643, 524, 190, 50]
    ClickImage($sGameResDir & "Maze_Trans.png", $fDefault, 960, 240, $bCD, $iCDFactor, $arrTransArea)
    ClickImage($sGameResDir & "Maze_EvOpts.png", $fDefault, -50, -25, $bCD, $iCDFactor, $arrEvOptsArea)
    If ClickImage($sGameResDir & "Maze_CraftDone.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrNotCraftArea) Then
        Sleep($iPopupDelay)
        ClickImage($sGameResDir & "Maze_CraftDoneOK.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrNotCraftOKArea)
    EndIf

    If IsArray(ImageSearch($sGameResDir & "Com_SkipLocked.png", $fDefault, $arrRU)) Then
        ActionPause(4500)
        Return
    EndIf

    If IsArray(ImageSearch($sGameResDir & "Com_TryAgain.png", $fDefault, $arrRB)) Or _
       IsArray(ImageSearch($sGameResDir & "Com_Limited.png", $fDefault, $arrRB)) Or _
       IsArray(ImageSearch($sGameResDir & "Quest_Clear.png", $fDefault, $arrRB)) Or _
       IsArray(ImageSearch($sGameResDir & "ADV_Menu.png", $fDefault, $arrRU)) Then
        ActionStop()
        Return
    EndIf

    Local $iTimerReaction = 500
    Local $arrDailyUnitArea = [630, 135, 135, 35]
    If ClickImage($sGameResDir & "MazeShop\Daily_Unit.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrDailyUnitArea) Then
        $bSingleRunning = True
        Sleep($iTimerReaction)
        If Not $bRunning Then Return

        Local $arrDailyClearArea = [315, 580, 70, 35]
        If IsArray(ImageSearch($sGameResDir & "MazeShop\Daily_Clear.png", $fLow, $arrDailyClearArea)) Then
            If $bMazeFarmingOn Then
                MazeShopFarming()
            Else
                _MazeShopAbort($fLow, $bCD, $iCDFactor)
            EndIf
        EndIf
        $bSingleRunning = False
    EndIf

    If $bWriteLogOn Then
        WriteLog("AutoClick: " & TimerDiff($hTimer) & " ms")
    EndIf
EndFunc

; Internal Handling
Func _OnAutoItExit()
    _GDIPlus_Shutdown()
    _OpenCV_Close()
EndFunc
