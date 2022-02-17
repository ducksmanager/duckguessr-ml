#!/bin/bash
dataset=$1
tensorflowjs_converter --input_format keras "$dataset".keras tfjs_model/"$dataset"