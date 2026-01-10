#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseX64=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include "Libs\autoit-opencv-com\udf\opencv_udf_utils.au3"
#include <GDIPlus.au3>

_OpenCV_Open("Libs\opencv\build\x64\vc16\bin\opencv_world4120.dll", "Libs\autoit-opencv-com\autoit_opencv_com4120.dll")
OnAutoItExitRegister("_OnAutoItExit")

Global $iSquare = 500
Example()
While $iSquare > 0
    Example()
    $iSquare -= 50
WEnd

Func WriteLog($msg)
    Local $hFile = FileOpen("Test_OpenCV.log", $FO_APPEND + $FO_CREATEPATH)
    If $hFile = -1 Then Return SetError(1, 0, 0)

    FileWriteLine($hFile, _
        @YEAR & "-" & @MON & "-" & @MDAY & " " & _
        @HOUR & ":" & @MIN & ":" & @SEC & " - " & $msg)

    FileClose($hFile)
EndFunc

Func Example()
    Local $hTimer = TimerInit()
    Local $cv = _OpenCV_get()
    If Not IsObj($cv) Then Return

    Local $imgPath = "Res\Patak.jpg"
    Local $imgCropPath = "Res\Patak_crop.jpg"
    Local $img = _OpenCV_imread_and_check(_OpenCV_FindFile($imgPath))
    _GDIPlus_Startup()
    Local $tmplGDI = _GDIPlus_ImageLoadFromFile(_OpenCV_FindFile($imgPath))
    Local $tmplCrop = _GDIPlus_BitmapCloneArea($tmplGDI, 520, 80, $iSquare, $iSquare, $GDIP_PXF32ARGB)
    _GDIPlus_ImageSaveToFile($tmplCrop, $imgCropPath)
    _GDIPlus_ImageDispose($tmplCrop)
    _GDIPlus_ImageDispose($tmplGDI)
    _GDIPlus_Shutdown()
    Local $tmpl = _OpenCV_imread_and_check(_OpenCV_FindFile($imgCropPath))

    Local $iTotalCost = $img.width * $img.height * $tmpl.width * $tmpl.height

    ; The higher the value, the higher the match is exact
    Local $threshold = 0.8

    Local $aMatches = _OpenCV_FindTemplate($img, $tmpl, $threshold)

    Local $iElapsed = TimerDiff($hTimer)
    WriteLog("TotalPixels: " & $iTotalCost & ", Elapsed: " & $iElapsed & " ms")

    ;~ Local $aRedColor = _OpenCV_RGB(255, 0, 0)
    ;~ Local $aMatchRect[4] = [0, 0, $tmpl.width, $tmpl.height]

    ;~ For $i = 0 To UBound($aMatches) - 1
    ;~     $aMatchRect[0] = $aMatches[$i][0]
    ;~     $aMatchRect[1] = $aMatches[$i][1]

    ;~     ; Draw a red rectangle around the matched position
    ;~     $cv.rectangle($img, $aMatchRect, $aRedColor, 2)
    ;~ Next

    ;~ $cv.imshow("Find template example", $img)
    ;~ $cv.waitKey()

    ;~ $cv.destroyAllWindows()
EndFunc   ;==>Example

Func _OnAutoItExit()
    _OpenCV_Close()
EndFunc   ;==>_OnAutoItExit
