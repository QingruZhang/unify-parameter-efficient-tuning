#! /bin/bash
#SBATCH --output=slurm_logs/slurm-%A-%a.out
#SBATCH --error=slurm_logs/slurm-%A-%a.err
#SBATCH --job-name=xsum
#SBATCH --nodes=1
#SBATCH --gres=gpu:A6000:1
#SBATCH --mem=30g
#SBATCH --cpus-per-task=2
#SBATCH --time=0
##SBATCH --array=0

export TRANSFORMERS_CACHE=checkpoints/hf_model
cache_dir=${TRANSFORMERS_CACHE}


# wandb env variables
export WANDB_PROJECT=xsum_effectune
export WANDB_WATCH="false"

DATE=`date +%Y%m%d`
dataset="xsum"

use_prefix="lisa"

max_steps=80000
warmup_updates=0
lr=5e-5
lr_scheduler_type="polynomial"
max_grad_norm=1
weight_decay=0
bsz=16
gradient_steps=4
metric=rouge2
ft='LN+PE'
max_eval_examples=1600
max_train_examples=160
logging_steps=100
label_smoothing_factor=0.

eval_strategy="steps"
# eval_strategy="steps"
save_steps=3000

exp_name=xsum_tride.prefix.${use_prefix}.ms${max_steps}.ls${label_smoothing_factor}.wd${weight_decay}.bias${add_bias_logits}
SAVE=checkpoints/${dataset}/${DATE}/${exp_name}

rm -rf ${SAVE}; mkdir -p ${SAVE}

python -u examples/pytorch/summarization/run_summarization.py \
    --dataset_name 'xsum' \
    --model_name_or_path 'facebook/bart-large' \
    --cache_dir ${cache_dir} \
    --use_prefix ${use_prefix} \
    --mid_dim 800 \
    --preseqlen 200 \
    --unfreeze_params ${ft} \
    --preprocessing_num_workers 2 \
    --max_source_length 512 \
    --max_target_length 128 \
    --val_max_target_length 60 \
    --max_eval_samples ${max_eval_examples} \
    --max_train_examples ${max_train_examples} \
    --num_beams 6 \
    --max_length 60 \
    --min_length 10 \
    --no_repeat_ngram_size 3 \
    --do_train \
    --do_eval \
    --per_device_train_batch_size ${bsz} \
    --per_device_eval_batch_size ${bsz} \
    --gradient_accumulation_steps ${gradient_steps} \
    --max_steps ${max_steps} \
    --learning_rate ${lr} \
    --lr_scheduler_type ${lr_scheduler_type} \
    --max_grad_norm ${max_grad_norm} \
    --weight_decay ${weight_decay} \
    --warmup_steps ${warmup_updates} \
    --fp16 \
    --logging_steps ${logging_steps} \
    --save_total_limit 2 \
    --label_smoothing_factor ${label_smoothing_factor} \
    --evaluation_strategy ${eval_strategy} \
    --save_strategy ${eval_strategy} \
    --save_steps ${save_steps} \
    --eval_steps ${save_steps} \
    --load_best_model_at_end \
    --report_to "wandb" \
    --run_name ${dataset}.${DATE}.${exp_name} \
    --overwrite_output_dir "True" \
    --disable_tqdm "True" \
    --metric_for_best_model ${metric} \
    --greater_is_better "True" \
    --predict_with_generate \
    --output_dir ${SAVE} 2>&1 | tee ${SAVE}/log.txt
    # --predict_with_generate
    # --metric_for_best_model ${metric} \
    # --greater_is_better "True" \

#rm -rf ${SAVE}/pytorch_model.bin
