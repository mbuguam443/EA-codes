#property strict

bool screenshot_taken = false;

int OnInit()
{
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   if(!screenshot_taken)
   {
      if(ChartScreenShot(0,"chart.png",1280,720,ALIGN_RIGHT))
      {
         Print("Screenshot saved.");
         screenshot_taken = true;
      }
   }
}