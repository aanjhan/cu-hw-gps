<?php

define("SEC_PER_DAY",24*60*60);

class Schedule
{
    var $errors=array();
    var $events=array();
    var $schedule=array();

    var $lastEvent="";
    
    function Schedule()
    {
        global $wgParser;
        $wgParser->setHook('schedule',array(&$this,'Render'));
    }

    function ParseInput($input)
    {
        $lineCount=0;
        $lines=split("\n",$input);
        foreach($lines as $line)
        {
            $lineCount++;

            if(strcmp($line,"")==0)continue;
            elseif(!preg_match('/^ *<item .*\/> *$/',$line))
            {
                $this->Error("Unrecognized format '$line' on line $lineCount.");
                continue;
            }

            $name="";
            $item=null;
    
            if(preg_match('/ +name="([^"]+)"/',$line,$m))$name=$m[1];
            else
            {
                $this->Error("Missing name on line $lineCount.");
                continue;
            }

            if(isset($this->events[$name]))
            {
                $this->Error("Duplicate entry '$name' on line $lineCount.");
                continue;
            }

            $item=array();
            if(preg_match('/ +length="(\d+)"/',$line,$m))$item["length"]=$m[1];
            else
            {
                $this->Error("Missing length on line $lineCount.");
                continue;
            }

            if(preg_match('/ +start="([^"]+)"/',$line,$m))$item["start"]=$m[1];
            if(preg_match('/ +owner="([^"]*)"/',$line,$m))$item["owner"]=$m[1];
            if(preg_match('/ +depend="([^"]*)"/',$line,$m))$item["depend"]=$m[1];

            if(preg_match('/ +complete="(\d{1,2}\/\d{1,2}\/\d{2})"/',$line,$m))$item["complete"]=$m[1];
            elseif(preg_match('/ +complete +/',$line))$item["complete"]="true";
            
            $this->events[$name]=$item;
        }
    }

    function EvalEntry($name)
    {
        if(isset($this->schedule[$name]))return true;

        $event=&$this->events[$name];

        //Determine start date.
        $start=0;
        if(preg_match('/(start|end|complete)\((.*)\)(([+-])(\d+))?/',$event["start"],$m))
        {
            $type=$m[1];
            $dep=$m[2];
            $op=$m[3];
            $val=$m[4];

            if(!$this->EvalEntry($dep))
            {
                $this->Error("Parsing start time for '$name'.");
                return false;
            }

            $start=$this->schedule[$dep][$type];
            if(strcmp($op,"")!=0){ $start+=(strcmp($op,"+")==0 ? $val : -$val)*SEC_PER_DAY; }
        }
        elseif(isset($event["start"]))$start=strtotime($event["start"]);
        elseif(preg_match('/(start|end|complete)\((.*)\)(([+-])(\d+))?/',$event["end"],$m))
        {
            $type=$m[1];
            $dep=$m[2];
            $op=$m[3];
            $val=$m[4];

            if(!EvalEntry($dep))
            {
                $this->Error("Parsing start time for '$name'.");
                return false;
            }

            $start=$this->schedule[$dep][$type]-$event["length"]*SEC_PER_DAY;
            if(strcmp($op,"")!=0){ $start+=(strcmp($op,"+")==0 ? $val : -$val)*SEC_PER_DAY; }
        }
        elseif(strcmp($event["depend"],"")!=0)
        {
            $depend=split(",",$event["depend"]);
            foreach ($depend as $dep)
            {
                $dep=trim($dep);

                if(!$this->EvalEntry($dep))
                {
                    $this->Error("Parsing dependencies for '$name'.");
                    return false;
                }

                //Is this the last dependency?
                if($start<$this->schedule[$dep]["finish"])
                {
                    $start=$this->schedule[$dep]["finish"];
                }
            }
        }
        else
        {
            if(strcmp($this->lastEvent,"")!=0)$start=$this->schedule[$this->lastEvent]["finish"];
            else $start=time();
        }

        $end=$start+$event["length"]*SEC_PER_DAY;

        $complete;
        if(!isset($event["complete"]))$complete="";
        elseif(strcmp($event["complete"],"true")==0)$complete=$end;
        else $complete=strtotime($event["complete"]);

        $entry=array();
        $entry["start"]=$start;
        $entry["end"]=$end;
        $entry["owner"]=$event["owner"];
        $entry["complete"]=$complete;
        $entry["depend"]=$event["depend"];
        $entry["finish"]=strcmp($complete,"")!=0 ? $complete : $end;
        $this->schedule[$name]=$entry;

        if(strcmp($this->lastEvent,"")==0 ||
           $entry["finish"]>$this->schedule[$this->lastEvent]["finish"])
        {
            $this->lastEvent=$name;
        }

        return true;
    }

    function Render($input,$args,$parser)
    {
        $output="";

        $this->ParseInput($input);
        foreach($this->events as $name=>$event)$this->EvalEntry($name);
        
        if(count($this->errors)>0)
        {foreach($this->errors as $error)
            {
                $output.="<strong class=\"error\">$error</strong><br>\n";
            }
        }
        else
        {
            $output=<<<END
{| class="wikitable" style="text-align:center"
|-
! Task Name
! Start Date
! End Date
! Complete
! Owner
! width="40%" | Dependencies
|-

END;
            uasort($this->schedule,array(&$this,'SortSchedule'));
            foreach($this->schedule as $name=>$event)
            {
                $output.="| align=left | $name\n";
                $output.="| ".date("n/j/y",$event["start"])."\n";
                $output.="| ".date("n/j/y",$event["end"])."\n";

                if(strcmp($event["complete"],"")!=0)
                {
                    $output.="| ".date("n/j/y",$event["complete"])."\n";
                }
                else
                {
                    $output.="|\n";
                }

                $output.="| ".$event["owner"]."\n";
                $output.="| ".$event["depend"]."\n";
                $output.="|-\n";
            }

            $output.="|}";
        }
        
        return $parser->recursiveTagParse($output);;
    }

    function Error($error)
    {
        array_push($this->errors,$error);
    }

    function SortSchedule($a,$b)
    {
        return $a["start"]-$b["start"];
    }
}

?>