#########################################################################
# Author:  Kevin RAHETILAHY                                             
# e-mail: kevin.rhtl@gmail.com                                          

# Credit Due : Boe Prox explains in detail about the use of runspaces and forms
# Link : http://learn-powershell.net/2012/10/14/powershell-and-wpf-writing-data-to-a-ui-from-a-different-runspace/ 

#########################################################################



$Global:syncProgress = [hashtable]::Synchronized(@{})
$syncProgress.WindowLeft= 150
$syncProgress.WindowTop = 100
$childRunspace =[runspacefactory]::CreateRunspace()
$childRunspace.ApartmentState = "STA"
$childRunspace.ThreadOptions = "ReuseThread"         
$childRunspace.Open()
$childRunspace.SessionStateProxy.SetVariable("syncProgress",$syncProgress)          
$PsChildCmd = [PowerShell]::Create().AddScript({   
    [xml]$xaml = @"
    <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="WindowProgress" WindowStyle="None" Width="800" Height="600" WindowStartupLocation="Manual" ShowInTaskbar="False" Top="100" Left="150" AllowsTransparency="True" >
        <Window.Background>
            <SolidColorBrush Opacity="0.8" Color="Black"/>
        </Window.Background>
			<Grid x:Name="ShowProgressBar" Visibility="Visible" HorizontalAlignment="Stretch" VerticalAlignment="Center" Height="180" Panel.ZIndex="20" Background="LightSlateGray" >
				<StackPanel Orientation="Vertical" Width="500" HorizontalAlignment="Center" >
					<Label x:Name = "ProgressLabelName" Content=" " Foreground="White" FontSize="16" Width = "300" HorizontalAlignment="Left" VerticalAlignment="Top" Margin = "10,10,10,0"/>
					<ProgressBar x:Name="ProgressBarName" Height = "20"  HorizontalAlignment="Stretch" Foreground="White" VerticalAlignment="Top" Margin = "10,10,10,10"/>
					<Button x:Name="CancelModal" Visibility="Collapsed" HorizontalAlignment="Right" Margin="0,0,10,0" Content="Exit" Width="50" Height = "20"/>
				</StackPanel>
            </Grid>
    </Window>
"@
  
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
    $syncProgress.Window=[Windows.Markup.XamlReader]::Load( $reader )
    $syncProgress.ProgressBar = $syncProgress.window.FindName("ProgressBarName")
    $syncProgress.Label = $syncProgress.window.FindName("ProgressLabelName")
    $syncProgress.Button = $syncProgress.window.FindName("CancelModal")
    

    $syncProgress.Window.Left=$syncProgress.WindowLeft
    $syncProgress.Window.Top=$syncProgress.WindowTop

    $syncProgress.Button.Dispatcher.Invoke([action]{
        $syncProgress.Button.Add_Click({
            $syncProgress.Window.Dispatcher.Invoke([action]{$syncProgress.Window.close()})
            $PsChildCmd.EndInvoke($Childproc) | Out-Null
            $childRunspace.Close() | Out-Null 
        })
    })
        
    $syncProgress.Window.ShowDialog() | Out-Null
    $syncProgress.Error = $Error
})


# ***********************************************************************

Function Launch_progress_modal{ 
    #launch the modal window with the progressbar
    $Script:PsChildCmd.Runspace = $childRunspace
    $Script:Childproc = $PsChildCmd.BeginInvoke()

    # we need to wait that all elements are loaded
    While (!($syncProgress.Window.IsInitialized)) { 
        Start-Sleep -Milliseconds 500 
    } 

    if($syncProgress.WindowLeft){ 
    $syncProgress.Window.Dispatcher.Invoke("Normal",[action]{
         $syncProgress.Window.Left=$syncProgress.WindowLeft 
         $syncProgress.Window.Top=$syncProgress.WindowTop
    })
    }
}

Function Close_progress_modal{
    $syncProgress.Window.Dispatcher.Invoke("Normal",[action]{$syncProgress.Window.close()})
    $Script:PsChildCmd.EndInvoke($Script:Childproc) | Out-Null
    #$Script:childRunspace.Close() | Out-Null 
}

Function show_Progress{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [String] $label,
        [Parameter(Position=1)]
        [int] $progress,
        [Parameter(Position=2)]
        [bool] $indeterminate
    )
    
     
    if(!$indeterminate){
        if(($progress -ge 0)-and ($progress -lt 100)){
	        $syncProgress.ProgressBar.Dispatcher.Invoke("Normal",[action]{   
			        $syncProgress.ProgressBar.IsIndeterminate = $False
			        $syncProgress.ProgressBar.Value= $progress
			        $syncProgress.ProgressBar.Foreground="LightGreen"
			        $syncProgress.Label.Content= $label +" : "+$progress+" %"
            })
        }
        elseif($progress -eq 100){
            $syncProgress.ProgressBar.Dispatcher.Invoke("Normal",[action]{   
			        $syncProgress.ProgressBar.IsIndeterminate = $False
			        $syncProgress.ProgressBar.Value= $progress
			        $syncProgress.ProgressBar.Foreground="LightGreen"
			        $syncProgress.Label.Content= $label +" : "+$progress+" %"
                    $syncProgress.Button.Visibility ="Visible" 
            })
        }
        else{Write-Warning "Out of range"}
    }
    else{
    $syncProgress.ProgressBar.Dispatcher.Invoke("Normal",[action]{   
			$syncProgress.ProgressBar.IsIndeterminate = $True
			$syncProgress.ProgressBar.Foreground="LightGreen"
            $syncProgress.Label.Content= $label
            $syncProgress.Button.Visibility ="Visible" 
      })
    }
}









