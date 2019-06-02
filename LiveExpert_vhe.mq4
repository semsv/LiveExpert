//+------------------------------------------------------------------------------------+
//|                                               LiveExpert_vhe.mq4                   |
//|                   Copyright 2016 Севастьянов Семен Владимирович, semen_s84@mail.ru |
//|                                              http://fx-fixprice.ru                 |
//+------------------------------------------------------------------------------------+
#property copyright   "2016 Севастьянов Семен Владимирович, semen_s84@mail.ru"
#property link        "http://fx-fixprice.ru"
#property description "LiveExpert virtual hosting edition"

#define MAGICMA  1122000692
//--- Inputs

input double Lots            = 0.01;        // Объем сделки (лот)
input int    LotCount        = 2;           // Максимальное кол-во сделок

input int    MovingPeriod_m1 = 14;          // Период 1-й MA для анализа точки входа
input int    MovingPeriod_m2 = 79;          // Период 2-й MA для анализа точки входа
 
input int    StopLoss        = 950;         // Фиксированный стоп лосс в пипсах
input int    TakeProffit     = 3500;        // Фиксированный тейк профит в пипсах
input double TrailingStop    = 300;         // Трайлинг в пипсах

input int    Sensivity       = 30;          // Чувствительность сигнала в пипсах
input int    ShiftInputPoint = 120;         // Сдвиг в пипсах от точки где хотел бы взять ордер робот
input int    RiskOffPoint    = 990;         // Риск в пипсах (сколько пипсов от точки входа должна оттойти цена для включения механизма трайлинга или безубытка)

input int    disable_signal_buy  = 1;       // Вкл./Выкл. сигналов на покупку
input int    disable_signal_sell = 0;       // Вкл./Выкл. сигналов на продажу
input int    disable_trailing    = 0;       // Вкл./Выкл. механизма трайлинг стоп
input bool   closeallorders      = false;   // Вкл. срипта закрывающего все открытые ордера (выполняется с подтверждением пользователя)

bool   close_all_openorders      = closeallorders;
double input_price_sell          = 0.0;
double input_price_buy           = 0.0;
int    _TakeProffit              = 0.0;
int    _StopLoss                 = 0.0;

double abs(double value)
{
  if (value > 0)
  {  
   return value;
  } else
  {
  return -1*value;
  }
}


//////////////////////////////////////
// Calculate optimal lot size       //                                
//////////////////////////////////////
double LotsOptimized()
  {
   double lot=Lots;
   return(lot);
  }
  
//////////////////////////////////////  
// сигнал на продажу                //
//////////////////////////////////////
bool signal_sell(double ma14_1, double ma14_2, double ma14_3, double ma26_1, double ma26_2, double ma26_3)
{
  if (disable_signal_sell == 1) 
   {
    input_price_sell = 0;
    return false;
   } 
  
  double spread = abs(Ask-Bid);
 /*
  if ( (
         (ma26_1 > ma14_1 && ma26_2 < ma14_2) || 
         (ma26_2 > ma14_2 && ma26_3 < ma14_3) ||
         (ma26_1 > ma14_1 && ma26_3 < ma14_3)
        ) && Bid > ma14_1
      ) 
    { if (input_price_sell==0) 
        {
          input_price_sell = Bid - ShiftInputPoint*Point;
          _TakeProffit     = TakeProffit;
          _StopLoss        = StopLoss;
        } 
      return true;
    }
    
   if (
      (Open[2] > ma14_2 + spread && Close[2] < ma14_2 - spread) &&
      (Open[1] < ma14_1 - spread && Close[1] < ma14_1 - spread) && 
      Bid > ma14_1
      )
   { if (input_price_sell==0) 
       {       
          input_price_sell  = Bid - ShiftInputPoint*Point;
          _TakeProffit      = TakeProffit;
          _StopLoss         = StopLoss;
       } 
     return true;
   } /**/
     
   if (Open[2]  < Close[2] &&
       abs(Close[2] - Open[1]) < Sensivity*Point &&
       Open[1]  < Close[1] &&
       (Close[1] - Open[1]) > 100 * Point &&
       Low[2] < ma14_1 &&
       High[2] > ma14_1 &&
       Open[1] > ma14_1 &&
       Close[1] > ma14_1 &&
       Open[2] > ma14_1 &&
       Close[2] > ma14_1 &&
       ma14_3   > ma26_3
      )
   {
     if (input_price_sell == 0) {
      input_price_sell = Close[1] + ShiftInputPoint*Point;
      _TakeProffit     = TakeProffit;
      _StopLoss        = StopLoss;
      if (_StopLoss > StopLoss || _StopLoss < 10) {_StopLoss = StopLoss;}
     }
     return true;
   } /**/    
  
  input_price_sell = 0;  
  return false;
}  

//////////////////////////////////////  
// сигнал на покупку                //
//////////////////////////////////////
bool signal_buy(double ma14_1, double ma14_2, double ma14_3, double ma26_1, double ma26_2, double ma26_3)
{
  if (disable_signal_buy == 1) 
  {
   input_price_buy = 0;
   return false;
  } 
  double spread = abs(Ask-Bid);
 
   if ( (
         (ma26_1 < ma14_1 && ma26_2 > ma14_2) || 
         (ma26_2 < ma14_2 && ma26_3 > ma14_3) ||
         (ma26_1 < ma14_1 && ma26_3 > ma14_3)
        ) && Ask > ma14_1
      ) 
    {
     if (input_price_buy == 0) {
        input_price_buy = Ask - ShiftInputPoint*Point;
        _TakeProffit    = TakeProffit;
        _StopLoss       = StopLoss;
       } return true;}
   if (
      (Open[2] < ma14_2 - spread && Close[2] > ma14_2 + spread) &&
      (Open[1] > ma14_1 + spread && Close[1] > ma14_1 + spread) && 
      Ask > ma14_1
      )
   { if (input_price_buy == 0) 
       {
        input_price_buy = Ask - ShiftInputPoint*Point;
        _TakeProffit    = TakeProffit;
        _StopLoss       = StopLoss;
       } return true;}   
           
  input_price_buy = 0;  
  _TakeProffit    = TakeProffit;
  _StopLoss       = StopLoss;
  return false;
} 
  
//+------------------------------------------------------------------+
//| Check for open order conditions                                  |
//+------------------------------------------------------------------+
void CheckForOpen()
  {
   
   int    res;
   if (OrdersTotal() > LotCount-1) return;
   
//--- go trading only for first tiks of new bar
   if(Volume[0]>1) return;
//--- get Moving Average 
   double ma1 = iMA(NULL,0, MovingPeriod_m1, 1, MODE_SMA, PRICE_CLOSE, 0);
   double ma2 = iMA(NULL,0, MovingPeriod_m1, 2, MODE_SMA, PRICE_CLOSE, 0);
   double ma3 = iMA(NULL,0, MovingPeriod_m1, 3, MODE_SMA, PRICE_CLOSE, 0);   
   
   double ma4 = iMA(NULL,0, MovingPeriod_m2, 1, MODE_SMA, PRICE_CLOSE, 0);
   double ma5 = iMA(NULL,0, MovingPeriod_m2, 2, MODE_SMA, PRICE_CLOSE, 0);
   double ma6 = iMA(NULL,0, MovingPeriod_m2, 3, MODE_SMA, PRICE_CLOSE, 0);   
//--- sell conditions
   if (
       signal_sell(ma1, ma2, ma3, ma4, ma5, ma6)
      )
     {
      if (abs(input_price_sell-Bid) < Sensivity*Point)
      {
       res = OrderSend(Symbol(), OP_SELL, LotsOptimized(),Bid,30,Bid+_StopLoss*Point,Bid-Point*_TakeProffit,"Hello World",MAGICMA,0,Red);
      } 
      return;
     }
//--- buy conditions
   if (
       signal_buy(ma1, ma2, ma3, ma4, ma5, ma6)
      )
     {
      if (abs(input_price_buy-Ask) < Sensivity*Point)
      {
       res = OrderSend(Symbol(), OP_BUY, LotsOptimized(),Ask,3,Ask-_StopLoss*Point,Ask+Point*_TakeProffit,"Hello World",MAGICMA,0,Blue);
      } 
      return;
     }
//---
  }
//+------------------------------------------------------------------+
//| Check for close order conditions                                 |
//+------------------------------------------------------------------+
void CheckForClose()
  {
  
int total=OrdersTotal();
  
//---
if (close_all_openorders) {

Print("BID-ASK", abs(MarketInfo(OrderSymbol(),MODE_BID) - MarketInfo(OrderSymbol(),MODE_ASK)));

int mb = MessageBox("Вы действительно хотите закрыть все ордера?", "Сообщение", MB_OKCANCEL); }
if (mb == IDOK)
{
  for(int cnt1=0;cnt1<total;cnt1++)
     {
       if(!OrderSelect(cnt1,SELECT_BY_POS,MODE_TRADES))
         continue;
       if(OrderType()==OP_BUY)
       {  
        
        if (!OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrGreen))
         {
           Print("OrderClose error ",GetLastError());
           continue;  
         }
       } else
       {
        if (!OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrAqua))
        {
         Print("OrderClose error ",GetLastError());
         continue;  
        } 
       } 
     }
 close_all_openorders = false;    
} else
{
 close_all_openorders = false;
}


//--- it is important to enter the market correctly, but it is more important to exit it correctly...   
   for(int cnt=0;cnt<total;cnt++)
     {
      if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
         continue;
                        
      if(OrderType()<=OP_SELL &&   // check for opened position 
         OrderSymbol()==Symbol())  // check for symbol
        {
         //--- long position is opened
         if(OrderType()==OP_BUY)
           {
            if (RiskOffPoint         > 0 && 
                Bid-OrderOpenPrice() > Point*RiskOffPoint)
            {              
              if (OrderStopLoss()<Bid-Point*5 && OrderOpenPrice() > OrderStopLoss())
              {
                if(!OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()+Point*5,OrderTakeProfit(),0,Green))
                  Print("OrderModify error ",GetLastError());
                return;
              }       
            }
           /////////////////////////////////////////////   
           // Механизм продвинутого трайлинг стопа   
           /////////////////////////////////////////////
            if ( OrderStopLoss()          < Low[1] && 
                 Low[1] -OrderOpenPrice() > Point*RiskOffPoint &&
                 RiskOffPoint       > 0)
              {
                if(!OrderModify(OrderTicket(),OrderOpenPrice(), Low[1],OrderTakeProfit(),0,Green))
                  Print("OrderModify error ",GetLastError());
                return;
              }
           ////////////////////////////////////////////////
             
            //--- check for trailing stop
            if(TrailingStop>0 && disable_trailing == 0)
              {
               if(Bid-OrderOpenPrice()>Point*TrailingStop &&
                  Bid-OrderOpenPrice()>Point*RiskOffPoint)
                 {
                  if(OrderStopLoss()<Bid-Point*TrailingStop*2)
                    {
                     //--- modify order and exit
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),Bid-Point*TrailingStop,OrderTakeProfit(),0,Green))
                        Print("OrderModify error ",GetLastError());
                     return;
                    }
                 }
              }
           }
         else // go to short position
           {          
            if (RiskOffPoint         > 0 && 
                OrderOpenPrice()-Ask > Point*RiskOffPoint)
            {
              if(OrderStopLoss()>Ask+Point*5 && OrderOpenPrice() < OrderStopLoss())
              {
                if(!OrderModify(OrderTicket(),OrderOpenPrice(), OrderOpenPrice()-Point*5,OrderTakeProfit(),0,Red))
                  Print("OrderModify error ",GetLastError());
                return;
              }     
           
           /////////////////////////////////////////////   
           // Механизм продвинутого трайлинг стопа   
           /////////////////////////////////////////////
              if(OrderStopLoss()>High[1] && 
                 OrderOpenPrice()-High[1] > Point*RiskOffPoint &&
                 RiskOffPoint       > 0)
              {
                if(!OrderModify(OrderTicket(),OrderOpenPrice(), High[1], OrderTakeProfit(), 0, Red))
                  Print("OrderModify error ",GetLastError());
                return;
              }                
            } 
          ////////////////////////////////////////////////
            
            //--- check for trailing stop
            if(TrailingStop>0 && disable_trailing == 0)
              {
               if((OrderOpenPrice()-Ask)>(Point*TrailingStop) &&
                  (OrderOpenPrice()-Ask)>(Point*RiskOffPoint) 
                 )
                 {
                  if((OrderStopLoss()>(Ask+Point*TrailingStop*2)) || (OrderStopLoss()==0))
                    {
                     //--- modify order and exit
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),Ask+Point*TrailingStop,OrderTakeProfit(),0,Red))
                        Print("OrderModify error ",GetLastError());
                     return;
                    }
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- check for history and trading
   if(Bars<100 || IsTradeAllowed()==false)
      return;
//--- calculate open orders by current symbol
   CheckForOpen();
   CheckForClose();
//---
  }
//+------------------------------------------------------------------+

void OnInit()
{
 close_all_openorders      = closeallorders;
}
