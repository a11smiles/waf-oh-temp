Configuration WindowsWebServer {

    Import-DscResource -ModuleName xPSDesiredStateConfiguration, xWebAdministration, xNetworking

    Node localhost {

        WindowsFeature WebServerRole
        {
		    Name = "Web-Server"
		    Ensure = "Present"
        }

        WindowsFeature WebManagementConsole
        {
            Name = "Web-Mgmt-Console"
            Ensure = "Present"
        }

        WindowsFeature WebManagementService
        {
            Name = "Web-Mgmt-Service"
            Ensure = "Present"
        }

        WindowsFeature ASPNet45
        {
		    Ensure = "Present"
		    Name = "Web-Asp-Net45"
        }

        WindowsFeature HTTPRedirection
        {
            Name = "Web-Http-Redirect"
            Ensure = "Present"
        }

        WindowsFeature CustomLogging
        {
            Name = "Web-Custom-Logging"
            Ensure = "Present"
        }

        WindowsFeature LogginTools
        {
            Name = "Web-Log-Libraries"
            Ensure = "Present"
        }

        WindowsFeature RequestMonitor
        {
            Name = "Web-Request-Monitor"
            Ensure = "Present"
        }

        WindowsFeature Tracing
        {
            Name = "Web-Http-Tracing"
            Ensure = "Present"
        }

        WindowsFeature BasicAuthentication
        {
            Name = "Web-Basic-Auth"
            Ensure = "Present"
        }

        WindowsFeature WindowsAuthentication
        {
            Name = "Web-Windows-Auth"
            Ensure = "Present"
        }

        WindowsFeature ApplicationInitialization
        {
            Name = "Web-AppInit"
            Ensure = "Present"
        }

        WindowsFeature IISManagement  
        {  
            Ensure          = 'Present'
            Name            = 'Web-Mgmt-Console'
            DependsOn       = '[WindowsFeature]WebServerRole'
        } 

        <#
            Install Dotnet Core Hosting Bundle
        #>
        xRemoteFile DownloadDotNetCoreHostingBundle {
            Uri = "https://go.microsoft.com/fwlink/?linkid=844461" #https://docs.microsoft.com/en-us/aspnet/core/publishing/iis
            DestinationPath = "C:\temp\dnhosting.exe"
            MatchSource = $false
            #Proxy = "optional, your corporate proxy here"
            #ProxyCredential = "optional, your corporate proxy credential here"
        }

        # Discover your product name and id with Get-WmiObject Win32_product | ft IdentifyingNumber,Name after installing it once
        xPackage InstallDotNetCoreHostingBundle {
            Name = "Microsoft ASP.NET Core Module"
            ProductId = "B1B05FBB-1255-4F5B-9BAF-43B971A92613"
            Arguments = "/quiet /norestart /log C:\temp\dnhosting_install.log"
            Path = "C:\temp\dnhosting.exe"
            DependsOn = @("[WindowsFeature]InstallIIS",
                          "[xRemoteFile]DownloadDotNetCoreHostingBundle")
        }

        Script PutDotNetOnPath {
            SetScript = {
                $env:Path = $env:Path + "C:\Program Files\dotnet\;"
            }
            TestScript = {
                return $env:Path.Contains("C:\Program Files\dotnet\;")
            }
            GetScript = {
                return @{
                    SetScript = $SetScript
                    TestScript = $TestScript
                    GetScript = $GetScript
                    Result = "Set dotnet path"
                }
            }
        }


        <#
            Configure Web Sites
        #>
        xWebAppPool DefaultAppPool {
            Name            = 'DefaultAppPool'
            Ensure          = 'Absent'
        }

        xWebsite DefaultSite
        {
            Ensure          = 'Absent'
            Name            = 'Default Web Site' 
            PhysicalPath    = 'C:\inetpub\wwwroot'
        }

        xWebAppPool WoodgroveBankUIWebAppPool {
            Name            = 'WoodgroveBankUIPool'
            DependsOn       = '[WindowsFeature]WebServerRole'
        }

        xWebsite WoodgroveBankUI   
        {  
            Ensure          = 'Present'
            Name            = 'WoodgroveBankUI'
            PhysicalPath    = 'D:\web'
            BindingInfo     = MSFT_xWebBindingInformation
                {
                    Protocol = 'HTTP'
                    Port = 80
                    HostName = '*'
                }
            State           = 'Started'
            ApplicationPool = 'WoodgroveBankUIPool'
            DependsOn       = '[xWebAppPool]WoodgroveBankUIWebAppPool'
        }
        
        xWebAppPool WoodgroveBankAPIWebAppPool {
            Name            = 'WoodgroveBankAPIPool'
            DependsOn       = '[WindowsFeature]WebServerRole'
        }
        
        xWebsite WoodgroveBankAPI   
        {  
            Ensure          = 'Present'
            Name            = 'WoodgroveBankAPI'
            PhysicalPath    = 'D:\api'
            BindingInfo     = MSFT_xWebBindingInformation
                {
                    Protocol = 'HTTP'
                    Port = 8080
                    HostName = '*'
                }
            State           = 'Started'
            ApplicationPool = 'WoodgroveBankAPIPool'
            DependsOn       = '[xwebAppPool]WoodgroveBankAPIWebAppPool'
        }


        <#
            Install Web Deploy
        #>
	    Script DownloadWebDeploy
        {
            TestScript = {
                Test-Path "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
            }
            SetScript ={
                $source = "http://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/WebDeploy_amd64_en-US.msi"
                $dest = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
                Invoke-WebRequest $source -OutFile $dest
            }
            GetScript = { @{Result = "WebDeployDownload"} }
		    DependsOn = "[WindowsFeature]WebServerRole"
        }

	    Package InstallWebDeploy
        {
            Ensure = "Present"  
            Path  = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
            Name = "Microsoft Web Deploy 3.6"
            ProductId = "{6773A61D-755B-4F74-95CC-97920E45E696}"
		    Arguments = "/quiet ADDLOCAL=ALL"
		    DependsOn = "[Script]DownloadWebDeploy"
        }

        Service StartWebDeploy
        {
		    Name = "WMSVC"
		    StartupType = "Automatic"
		    State = "Running"
		    DependsOn = "[Package]InstallWebDeploy"
        }

      }
}