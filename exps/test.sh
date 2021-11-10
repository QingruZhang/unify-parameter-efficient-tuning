#! /bin/bash
#SBATCH --output=slurm_logs/slurm-%A-%a.out
#SBATCH --error=slurm_logs/slurm-%A-%a.err
#SBATCH --job-name=xsum.lora.init.2.comb
#SBATCH --nodes=1
#SBATCH --gres=gpu:a100:1
#SBATCH --mem=30g
#SBATCH --cpus-per-task=2
#SBATCH --time=0
##SBATCH --array=0

source activate tride
which python

export TRANSFORMERS_CACHE=/home/chuntinz/tir5/pretrain_models/huggingface
export HF_DATASETS_CACHE=/home/chuntinz/tir5/pretrain_models/huggingface
export HF_METRICS_CACHE=/home/chuntinz/tir5/pretrain_models/huggingface
cache_dir=/home/chuntinz/tir5/pretrain_models/huggingface

# wandb env variables
export WANDB_PROJECT=xsum_tride
export WANDB_WATCH="false"

DATE=`date +%Y%m%d`
dataset="xsum"

attn_gate="none"
ffn_gate="none"

#attn_mode="adapter"
#attn_option="attn_adapter"
#ffn_mode="adapter"
#ffn_option="ffn_hi_input"
#preseqlen=200
#ffn_bn_len=200

attn_mode="lisa"
attn_option="concat"
ffn_mode="adapter"
ffn_option="ffn_hi_input"
preseqlen=30
ffn_bn_len=512

# ffn Hi adapter with learned scalar, bert init
#attn_mode="none"
#attn_option="none"
#ffn_mode="adapter"
#ffn_option="ffn_hi_input"
#preseqlen=1
#ffn_bn_len=512
#adapter_init_option="bert"
#adapter_layernorm_option="learnable_scalar"
#adapter_scalar=2

# ffn Hi adapter with fixed scalar, bert init
#attn_mode="none"
#attn_option="none"
#ffn_mode="adapter"
#ffn_option="ffn_hi_input"
#preseqlen=1
#ffn_bn_len=512
#adapter_init_option="bert"
#adapter_layernorm_option="fixed_scalar"
#adapter_scalar=2

## ffn Hi adapter with learned scalar, lora init
#attn_mode="none"
#attn_option="none"
#ffn_mode="adapter"
#ffn_option="ffn_hi_input"
#preseqlen=1
#ffn_bn_len=512
#adapter_init_option="lora"
#adapter_layernorm_option="learnable_scalar"
#adapter_scalar=2

# ffn Hi adapter with fixed scalar, lora init
attn_mode="none"
attn_option="none"
ffn_mode="adapter"
ffn_option="ffn_hi_input"
preseqlen=1
ffn_bn_len=512
adapter_init_option="lora"
adapter_layernorm_option="fixed_scalar"
adapter_scalar=2

# ffn Hi adapter with fixed scalar, lora init
#attn_mode="lisa"
#attn_option="concat"
#ffn_mode="adapter"
#ffn_option="ffn_hi_input"
#preseqlen=30
#ffn_bn_len=512
#adapter_init_option="lora"
#adapter_layernorm_option="fixed_scalar"
#adapter_scalar=2

mh_reuse_proj="True"
adapter_post_layernorm=0

max_steps=100000
num_train_epochs=30
warmup_updates=0
lr=5e-5
lr_scheduler_type="polynomial"
max_grad_norm=0.1
weight_decay=0.01
bsz=16
gradient_steps=4
metric=rouge2
ft='ef_'
top_layers=12
max_eval_samples=1600
max_train_samples=2000
logging_steps=100
label_smoothing_factor=0.1

eval_strategy="steps"
save_steps=3000
report_to="wandb"

debug=0
extra_cmd=""
debug_str=""

if [ "${debug}" = 1 ];
then
    label_smoothing_factor=0
    weight_decay=0
    max_grad_norm=1
    max_train_samples=2000
    bsz=24
    gradient_steps=2
    num_train_epochs=30
    max_steps=-1
    eval_strategy='steps'
    save_steps=100
    report_to="none"
    logging_steps=10
    extra_cmd="--max_train_samples ${max_train_samples}"
    debug_str=".debug"
fi

exp_name=xsum_tride.am_${attn_mode}.ao_${attn_option}.fm_${ffn_mode}.fo_${ffn_option}.abn${preseqlen}.fbn${ffn_bn_len}.ainit_${adapter_init_option}.alo_${adapter_layernorm_option}.as_${adapter_scalar}.unfreeze_${ft}.ms${max_steps}.ls${label_smoothing_factor}.warm${warmup_updates}.wd${weight_decay}${debug_str}
SAVE=checkpoints/${dataset}/${DATE}/${exp_name}
rm ${HF_DATASETS_CACHE}/downloads/*.lock
rm ${HF_DATASETS_CACHE}/*.lock

python -u examples/pytorch/summarization/run_summarization.py \
    --dataset_name 'xsum' \
    --model_name_or_path 'facebook/bart-large' \
    --load_path checkpoints/xsum/20210924/xsum_tride.am_none.ao_none.fm_adapter.fo_ffn_hi_input.abn1.fbn512.ainit_lora.alo_fixed_scalar.as_2.unfreeze_ef_.ms100000.ls0.1.warm0.wd0.01/checkpoint-99000 \
    --cache_dir ${cache_dir} \
    --attn_mode ${attn_mode} \
    --attn_option ${attn_option} \
    --ffn_mode ${ffn_mode} \
    --ffn_option ${ffn_option} \
    --attn_gate ${attn_gate} \
    --ffn_gate ${ffn_gate} \
    --adapter_layernorm_option ${adapter_layernorm_option} \
    --adapter_init_option ${adapter_init_option} \
    --adapter_scalar ${adapter_scalar} \
    --mh_reuse_proj ${mh_reuse_proj} \
    --mid_dim 800 \
    --preseqlen ${preseqlen} \
    --ffn_bn_len ${ffn_bn_len} \
    --init_with_bert 1 \
    --unfreeze_params ${ft} \
    --num_bias_layers ${top_layers} \
    --preprocessing_num_workers 2 \
    --max_source_length 512 \
    --max_target_length 128 \
    --val_max_target_length 60 \
    --max_eval_samples ${max_eval_samples} \
    --num_beams 6 \
    --max_length 60 \
    --min_length 10 \
    --no_repeat_ngram_size 3 \
    --do_eval \
    --do_predict \
    --per_device_train_batch_size ${bsz} \
    --per_device_eval_batch_size ${bsz} \
    --gradient_accumulation_steps ${gradient_steps} \
    --max_steps ${max_steps} \
    --num_train_epochs ${num_train_epochs} \
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
    --report_to "none" \
    --run_name ${dataset}.${DATE}.${exp_name} \
    --overwrite_output_dir "False" \
    --disable_tqdm "True" \
    --metric_for_best_model ${metric} \
    --greater_is_better "True" \
    --predict_with_generate \
    --output_dir ${SAVE} ${extra_cmd} 2>&1 | tee ${SAVE}/log.txt
