
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
CTrade trade;
CPositionInfo posinfo;
COrderInfo  orderinfo;
CHistoryOrderInfo hisinfo;
CDealInfo dealinfo;

enum enumLotType{Fixed_Lots=0,Pct_of_Balance=1,Pct_of_Equity=2,Pct_of_Free_Margin=3};

input group "Group Settings";
input int InpMagic=12345;
input int Slippage=1;

input group "Time Settings";
input int StartHour=16;
input int EndHour=17;
input int Secs=60;

input group "Money Management";
input enumLotType LotType=0;
input double FixedLot=0.01;
input double RiskPercent=0.5;


input group "Trading Setting in points";
input double Delta=0.5;
input double MaxDistance=0.01;
input double Stop=10;
input double MaxTrailing=4;
input int  MaxSpread=5555;

double DeltaX=Delta;

double MinOrderDistance=0.5;
double MaxTrailingLimit=7.5;
double OrderModificationFactor=3;
int    TickCounter=0;
double PriceToPipRatio=0;

//9:328h
double BaseTrailingStop=0;
double TrailingStopBuffer=0;
double TrailingStopIncrement=0;
double TrailingStopThreshold=0;
long   AccountLeverageValue=0;

double LotStepSize=0;
double MaxLotSize=0;
double MinLotSize=0;
double MarginPerMinLot=0;
double MinStopDistance=0;

int    BrokerStopLevel=0;
double MinFreezeDistance=0;
int    BrokerFreezeLevel=0;
double CurrentSpread=0;
double AverageSpread=0;

int    EAModeFlag=0;
int    SpreadArraySize=0;
int    DefaultSpreadPeriod=30;
double MaxAllowedSpread=0;
double CalculatedLotSize=0;

double CommissionPerPip=0;
int    SpreadMultiplier=0;
double AdjustedOrderDistance=0;
double MinOrderModification=0;
double TrailingStopActive=0;

double TrailingStopMax=0;
double MaxOrderPlacementDistance=0;
double OrderPlacementStep=0;
double CalculatedStopLoss=0;
bool   AllowBuyOrders=false;


bool AllowSellOrders=false;
bool SpreadAcceptable=false;
int  LastOrderTimeDiff=0;
int  LastOrderTime=0;
int  MinOrderInterval=0;

double CurrentBuySL=0;
string orderCommentText="Mr Mbugua";
int    LastBuyOrderTime=0;
bool   TradeAllowed=false;
double currentSellSL=0;

int LastSellOrderTime=0;
int OrderCheckFrequency=2;
int SpreadCalculationMethod=1;
bool EnableTrading=false;
double SpreadHistroyArray[];

   



int OnInit()
  {
    Print("Am here");
   trade.SetExpertMagicNumber(InpMagic);
   if((MinOrderDistance>Delta))
     {
       DeltaX=(MinOrderDistance+0.1);
     }
   if((MaxTrailing>MaxTrailingLimit))
     {
      MaxTrailingLimit=(MaxTrailing+0.1);
     }
   if((OrderModificationFactor<1))
     {
      OrderModificationFactor=1;
     }  
     TickCounter=0;
     PriceToPipRatio=0;
     BaseTrailingStop=TrailingStopBuffer;
     TrailingStopIncrement=TrailingStopThreshold;
     AccountLeverageValue=AccountInfoInteger(ACCOUNT_LEVERAGE);
     
     
     LotStepSize=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
     MaxLotSize=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
     MinLotSize=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
     MarginPerMinLot=SymbolInfoDouble(_Symbol,SYMBOL_MARGIN_INITIAL)*MinLotSize;
     MinStopDistance=0;
     
     BrokerStopLevel=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
     if(BrokerStopLevel>0)MinStopDistance=(BrokerStopLevel+1)*_Point;
     
     MinFreezeDistance=0;
     BrokerFreezeLevel=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
     if(BrokerFreezeLevel>0) MinFreezeDistance=(BrokerFreezeLevel+1)*_Point;
     
     
     if(BrokerStopLevel >0 || BrokerFreezeLevel >0)
       {
        Comment("Warning Broker is Not Suitable, the stoplevel is greater than zero");
       }
     
    double Ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
    double Bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
    
    CurrentSpread=NormalizeDouble(Ask-Bid,_Digits);
    AverageSpread=CurrentSpread;
    
    SpreadArraySize=(EAModeFlag==0)?DefaultSpreadPeriod:3;
    ArrayResize(SpreadHistroyArray,SpreadArraySize,0);
    
    MaxAllowedSpread=NormalizeDouble((MaxSpread*_Point),_Digits);
    
    TesterHideIndicators(true);
     
     
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    int CurrentTime=(int)TimeCurrent();
    int PendingBuyCount=0;
    int PendingSellCount=0;
    int OpenBuyCount=0;
    int OpenSellCount=0;
    int TotalBuyCount=0;
    int TotalSellCount=0;
    double OrderLotsValue=0;
    double OrderStopLossValue=0;
    double OrderTakeProfitValue=0;
    double OrderOpenPriceValue=0;
    double NewOrderTakeProfit=0;
    double BuyOrdersPriceSum=0;
    double BuyOrderLotSum=0;
    double SellOrderPriceSum=0;
    double SellOrderLotSum=0;
    double AverageBuyPrice=0;
    double AverageSellPrice=0;
    double LowestBuyPrice=99999;
    double HighestSellPrice=0;
    
    TickCounter++;
    
    if(PriceToPipRatio==0)
      {
         HistorySelect(0,TimeCurrent());
         for(int i=HistoryDealsTotal()-1;i>=0;i--)
           {
            ulong ticket=HistoryDealGetTicket(i);
            if(ticket==0) continue;
            
            if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol)continue;
            if(HistoryDealGetDouble(ticket,DEAL_PROFIT)==0)continue;
            if(HistoryDealGetInteger(ticket,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
            
            ulong posID=HistoryDealGetInteger(ticket,DEAL_POSITION_ID);
            if(posID==0) continue;
            if(HistoryDealSelect(posID))
              {
                double entryPrice =HistoryDealGetDouble(posID,DEAL_PRICE);
                double exitPrice  =HistoryDealGetDouble(ticket,DEAL_PRICE);
                double profit     =HistoryDealGetDouble(ticket,DEAL_PROFIT);
                double commission =HistoryDealGetDouble(ticket,DEAL_COMMISSION);
                
                if(exitPrice!=entryPrice)
                  {
                   PriceToPipRatio=fabs(profit/(exitPrice-entryPrice));
                   CommissionPerPip=-commission/PriceToPipRatio;
                   break;
                  }
              }
            
           }
      }
    
    double Ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
    double Bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
    
    double newSpread=NormalizeDouble(Ask-Bid,_Digits);
    ArrayCopy(SpreadHistroyArray,SpreadHistroyArray,0,1,SpreadArraySize+1);
    SpreadHistroyArray[SpreadArraySize-1]=newSpread;
    
    
    double sum=0;
    for(int i=0;i<SpreadArraySize;i++)
      {
        sum+=SpreadHistroyArray[i];
      }
    CurrentSpread=sum/SpreadArraySize;
    
    AverageSpread=MathMax(SpreadMultiplier*_Point, CurrentSpread+CommissionPerPip);
    
    AdjustedOrderDistance=MathMax(AverageSpread * Delta, MinStopDistance);
    MinOrderModification =MathMax(AverageSpread * MinOrderDistance,MinFreezeDistance);
    
    
    TrailingStopActive=AverageSpread*MaxTrailing;
    TrailingStopMax   =AverageSpread * MaxTrailingLimit;
    MaxOrderPlacementDistance=AverageSpread * MaxDistance;
    OrderPlacementStep=MinOrderModification/OrderModificationFactor;
    CalculatedStopLoss=MathMax(AverageSpread*Stop, MinStopDistance);
    
    for(int i=PositionsTotal()-1;i>=0;i--)
      {
        if(posinfo.SelectByIndex(i)&&
           posinfo.Symbol()==_Symbol &&
           posinfo.Magic()==InpMagic)
          {
            double price=posinfo.PriceOpen();
            double lots=posinfo.Volume();
            double sl=posinfo.StopLoss();
            if(posinfo.PositionType()==POSITION_TYPE_BUY)
              {
                 OpenBuyCount++;
                 if(sl==0 || (sl>0 && sl<price)) TotalBuyCount++;
                 CurrentBuySL=sl;
                 BuyOrdersPriceSum+=price*lots;
                 BuyOrderLotSum+=lots;
                 if(price < LowestBuyPrice) LowestBuyPrice=price;
            }else if(posinfo.PositionType()==POSITION_TYPE_SELL)
            {
                OpenSellCount++;
                if(sl==0 || (sl>0 && sl > price)) TotalSellCount++;
                currentSellSL=sl;
                SellOrderPriceSum+=price*lots;
                SellOrderLotSum+=lots;
                if(price>HighestSellPrice) HighestSellPrice=price;
            
            }
            
          }
      }
      
//......................................................      
    for(int i=OrdersTotal()-1;i>=0;i--)
      {
        if(orderinfo.SelectByIndex(i) &&
           orderinfo.Symbol()==_Symbol &&
           orderinfo.Magic()==InpMagic)
          {
             if(orderinfo.OrderType()==ORDER_TYPE_BUY_STOP)
               {
                PendingBuyCount++;
                TotalBuyCount++;
               }
             else if(orderinfo.OrderType()==ORDER_TYPE_SELL_STOP)
               {
                PendingSellCount++;
                TotalSellCount++;
               }  
          }
      }  
//.........................................
   if((BuyOrderLotSum >0))
     {
      AverageBuyPrice=NormalizeDouble((BuyOrdersPriceSum/BuyOrderLotSum),_Digits);
     }
   if((SellOrderLotSum>0))
     {
     AverageSellPrice=NormalizeDouble((SellOrderPriceSum/SellOrderLotSum),_Digits);  
     } 
     
    MqlDateTime BrokerTime;
    TimeCurrent(BrokerTime);
    
    for(int i=OrdersTotal()-1;i>=0;i--)
      {
        if(!orderinfo.SelectByIndex(i)) continue;
        if(orderinfo.Symbol()!=_Symbol || orderinfo.Magic()!=InpMagic) continue;
        
        ulong ticket = orderinfo.Ticket();
        ENUM_ORDER_TYPE  type=orderinfo.OrderType();
        double openPrice=orderinfo.PriceOpen();
        double sl=orderinfo.StopLoss();
        double tp=orderinfo.TakeProfit();
        double lots=orderinfo.VolumeCurrent();
        
        if(type==ORDER_TYPE_BUY_STOP)
          {
            bool allowTrade=(BrokerTime.hour>= StartHour && BrokerTime.hour<=EndHour);
            if(AverageSpread > MaxAllowedSpread || !allowTrade)
              {
                trade.OrderDelete(ticket);
                continue;
              }
            int timeDiff=(int)(CurrentTime-LastBuyOrderTime);
            bool needModification=(timeDiff>Secs)||
                                  (TickCounter % OrderCheckFrequency==0 &&
                                  ((OpenBuyCount<1 && (openPrice - SymbolInfoDouble(_Symbol,SYMBOL_ASK))<MinOrderModification) ||
                                  (openPrice - SymbolInfoDouble(_Symbol,SYMBOL_ASK))<OrderPlacementStep ||
                                  (openPrice - SymbolInfoDouble(_Symbol,SYMBOL_ASK))>MaxOrderPlacementDistance));
            if(needModification==true)
              {
                double distance=AdjustedOrderDistance;
                if(OpenBuyCount>0) distance/=OrderModificationFactor;
                distance=MathMax(distance,MinStopDistance);
                
                double modifiedPrice=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK)+distance,_Digits);
                double modifiedSl=(OpenBuyCount>0)?CurrentBuySL: NormalizeDouble(modifiedPrice-CalculatedStopLoss,_Digits);
                
                if((OpenBuyCount==0 || modifiedPrice > AverageBuyPrice)&&
                   modifiedPrice!=openPrice &&
                   (openPrice=SymbolInfoDouble(_Symbol,SYMBOL_ASK))>MinFreezeDistance
                  )
                  {
                    trade.OrderModify(ticket,modifiedPrice,modifiedSl,tp,0,0);
                    LastBuyOrderTime=CurrentTime;
                  }
                
              }                       
              
          }else if(type==ORDER_TYPE_SELL_STOP)
          {
            bool allowTrade=(BrokerTime.hour >= StartHour && BrokerTime.hour <=EndHour);
            if(AverageSpread > MaxAllowedSpread || !allowTrade)
              {
                trade.OrderDelete(ticket);
                continue;
              }
            int timeDiff=(int)(CurrentTime - LastSellOrderTime);
            bool needModification=(timeDiff>Secs) ||
                                  (TickCounter % OrderCheckFrequency ==0 &&
                                   ((OpenSellCount <1 && (SymbolInfoDouble(_Symbol,SYMBOL_BID)-openPrice)<MinOrderModification)||
                                   (SymbolInfoDouble(_Symbol,SYMBOL_BID)-openPrice)< OrderPlacementStep ||
                                   (SymbolInfoDouble(_Symbol,SYMBOL_BID)-openPrice)>MaxOrderPlacementDistance
                                   ));
            if(needModification==true)
              {
                double distance=AdjustedOrderDistance;
                if(OpenSellCount >0) distance/=OrderModificationFactor;
                distance=MathMax(distance,MinStopDistance);
                
                
                double modifiedPrice=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID)-distance,_Digits);
                double modifiedSl   =(OpenSellCount>0) ? currentSellSL : NormalizeDouble(modifiedPrice+CalculatedStopLoss,_Digits);
                if((OpenSellCount==0 || modifiedPrice <AverageSellPrice)&&
                  modifiedPrice!=openPrice &&
                  (SymbolInfoDouble(_Symbol,SYMBOL_BID)-openPrice)>MinFreezeDistance )
                  
                  {
                    trade.OrderModify(ticket,modifiedPrice,modifiedSl,tp,0,0);
                    LastSellOrderTime=CurrentTime;
                  }
              }                       
                            
          
          }
      }
      
   
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
       if(!posinfo.SelectByIndex(i))continue;
       if(posinfo.Symbol()!=_Symbol || posinfo.Magic()!=InpMagic)continue;
       
       ulong ticket=posinfo.Ticket();
       ENUM_POSITION_TYPE type=posinfo.PositionType();
       double openPrice=posinfo.PriceOpen();
       double sl=posinfo.StopLoss();
       double tp=posinfo.TakeProfit();
       
       if(type==POSITION_TYPE_BUY)
         {
          double pricemove=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_BID)-openPrice+CommissionPerPip,0);
          double trailDist=CalculateTrailingStop(pricemove,MinStopDistance,TrailingStopActive,BaseTrailingStop,TrailingStopMax);
          
          double modifiedSl=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID)-trailDist,_Digits);
          double triggerLevel=openPrice +CommissionPerPip+TrailingStopIncrement;
          
          if((SymbolInfoDouble(_Symbol,SYMBOL_BID)-triggerLevel)>trailDist &&
            (sl==0 || (SymbolInfoDouble(_Symbol,SYMBOL_BID)-sl)>trailDist) &&
            modifiedSl!=sl)
 
            {
               trade.PositionModify(ticket,modifiedSl,tp);
            }
          
         }else if(type==POSITION_TYPE_SELL)
         {
          double pricemove=MathMax(openPrice-SymbolInfoDouble(_Symbol,SYMBOL_ASK)-CommissionPerPip,0);
          double trailDist=CalculateTrailingStop(pricemove,MinStopDistance,TrailingStopActive,BaseTrailingStop,TrailingStopMax);
          double modifiedSl=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK)+trailDist,_Digits);
          double triggerLevel=openPrice-CommissionPerPip+TrailingStopIncrement;
          
          if((triggerLevel - SymbolInfoDouble(_Symbol,SYMBOL_ASK))>trailDist &&
             (sl==0 || (sl-SymbolInfoDouble(_Symbol,SYMBOL_ASK))>trailDist)&&
             modifiedSl!=sl)              
               {
                trade.PositionModify(ticket,modifiedSl,tp);
               }          
         }
       
     }   
     
     if((OrderModificationFactor >1 && TotalBuyCount <1) || OpenBuyCount <1)
       {
         if(PendingBuyCount< 1)
           {
            bool spreadOK=(AverageSpread <= MaxAllowedSpread);
            bool timeOK =(BrokerTime.hour >= StartHour && BrokerTime.hour <=EndHour);
            if(spreadOK && timeOK && (CurrentTime - LastOrderTime) >MinOrderInterval && EAModeFlag==0)
              {
               if(LotType==0)
                 {
                  CalculatedLotSize=MathCeil(FixedLot/LotStepSize)*LotStepSize;
                  CalculatedLotSize=MathMax(CalculatedLotSize,MinLotSize);
                  
                 }else if(LotType>0)
                 {
                  CalculatedLotSize=calcLots(CalculatedStopLoss);
                 }
                 
               double marginRequired=0.0;
               double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
               if(OrderCalcMargin(ORDER_TYPE_BUY_STOP,_Symbol,CalculatedLotSize,ask,marginRequired)&&
                  AccountInfoDouble(ACCOUNT_MARGIN_FREE) >marginRequired )
                 
                 {
                     double orderDist =MathMax(MathMax(AdjustedOrderDistance,MinFreezeDistance),MinStopDistance);
                     double orderPrice=NormalizeDouble(ask+orderDist,_Digits);
                     double orderSL=(OpenBuyCount >0)?CurrentBuySL :NormalizeDouble(orderPrice-CalculatedStopLoss,_Digits);
                     if(trade.OrderOpen(_Symbol,ORDER_TYPE_BUY_STOP,CalculatedLotSize,orderPrice,ask,orderSL,NewOrderTakeProfit,0,0,orderCommentText))
                       {
                        LastBuyOrderTime=(int)TimeCurrent();
                        LastOrderTime=(int)TimeCurrent();
                       }
                 }
                 
              }
           }
       } 
       
   
   if((OrderModificationFactor>1 && TotalSellCount < 1) ||OpenSellCount <1)
     {
       if(PendingSellCount <1)
         {
           bool spreadOK=(AverageSpread<=MaxAllowedSpread);
           bool timeOK  =(BrokerTime.hour >= StartHour && BrokerTime.hour <=EndHour);
           
           if(spreadOK && timeOK && (CurrentTime-LastOrderTime)>MinOrderInterval && EAModeFlag==0)
             {
               if(LotType==0)
                 {
                  CalculatedLotSize=MathCeil(FixedLot/LotStepSize)*LotStepSize;
                  CalculatedLotSize=MathMax(CalculatedLotSize,MinLotSize);
                  
                 }else if(LotType>0)
                 {
                   CalculatedLotSize=calcLots(CalculatedStopLoss);
                 }
                double marginRequired=0.0;
                double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
                if(OrderCalcMargin(ORDER_TYPE_SELL_STOP,_Symbol,CalculatedLotSize,Bid,marginRequired)&&
                  AccountInfoDouble(ACCOUNT_MARGIN_FREE)>marginRequired)
                  {
                   double orderDist=MathMax(MathMax(AdjustedOrderDistance,MinFreezeDistance),MinStopDistance);
                   double orderPrice=NormalizeDouble(bid-orderDist,_Digits);
                   double orderSL=(OpenSellCount >0) ? currentSellSL :NormalizeDouble(orderPrice+CalculatedStopLoss, _Digits);
                   
                   if(trade.OrderOpen(_Symbol,ORDER_TYPE_SELL_STOP,CalculatedLotSize,orderPrice,bid,orderSL,NewOrderTakeProfit,0,0,orderCommentText))
                     {
                       LastSellOrderTime=(int)TimeCurrent();
                       LastOrderTime=(int)TimeCurrent();
                     }
                   
                  }  
             }
           
         }
     }
             
   
  }


double CalculateTrailingStop(double priceMove, double minDist, double activeDist, double baseDist, double maxDist)
{

  if(maxDist==0) return MathMax(activeDist,minDist);
  double ratio =priceMove/maxDist;
  double dynamicDist=(activeDist-baseDist) * ratio + baseDist;
  
  return MathMax(MathMin(dynamicDist,activeDist),minDist);
}


//55:10
double calcLots(double slPoints)
{
  double lots=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
  double accountBalance=AccountInfoDouble(ACCOUNT_BALANCE);
  double EquityBalance=AccountInfoDouble(ACCOUNT_EQUITY);
  double FreeMargin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  
  double risk=0;
  
  switch(LotType)
    {
     case 0:lots=FixedLot; return lots;
     case 1:risk=accountBalance *RiskPercent/100; break;
     case 2:risk=EquityBalance*RiskPercent/100;break;
     case 3:risk=FreeMargin*RiskPercent/100;
    }
    
    double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
    double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
    double lotstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
    
    double moneyPerLotStep=slPoints/tickSize*tickValue*lotstep;
    
    double minvolume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
    double maxvolume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
    double volumelimit=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT);
    
    if(volumelimit!=0) lots=MathMin(lots,volumelimit);
    if(maxvolume!=0)lots=MathMin(lots,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX));
    if(minvolume!=0)lots=MathMax(lots,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN));
    lots=NormalizeDouble(lots,2);
    
    return lots;
    
  
}