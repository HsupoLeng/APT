import PoseUNet_dataset as PoseUNet
import PoseUMDN_dataset as PoseUMDN
import PoseCommon_dataset as PoseCommon
import convNetBase as CNB
import PoseTools
import sys
import os
import tensorflow as tf
import imageio
import localSetup
from scipy.ndimage.interpolation import zoom
import numpy as np
import logging
import traceback
from scipy import stats
from tensorflow.contrib.slim.nets import resnet_v1
import tensorflow.contrib.slim as slim
from PoseCommon_dataset import conv_relu3, conv_relu
from tensorflow.contrib.layers import batch_norm
import resnet_official
import urllib
import tarfile
import math

class PoseUNet_resnet(PoseUNet.PoseUNet):

    def __init__(self, conf, name='unet_resnet'):
        conf.use_pretrained_weights = True
        self.conf = conf
        self.out_scale = 1.
        self.resnet_source = self.conf.get('mdn_resnet_source','slim')
        PoseUNet.PoseUNet.__init__(self, conf, name=name)

        if self.resnet_source == 'official_tf':
            url = 'http://download.tensorflow.org/models/official/20181001_resnet/savedmodels/resnet_v2_fp32_savedmodel_NHWC.tar.gz'
            script_dir = os.path.dirname(os.path.realpath(__file__))
            wt_dir = os.path.join(script_dir,'pretrained')
            wt_file = os.path.join(wt_dir,'resnet_v2_fp32_savedmodel_NHWC','1538687283','variables','variables.index')
            if not os.path.exists(wt_file):
                print('Downloading pretrained weights..')
                if not os.path.exists(wt_dir):
                    os.makedirs(wt_dir)
                sname, header = urllib.urlretrieve(url)
                tar = tarfile.open(sname, "r:gz")
                print('Extracting pretrained weights..')
                tar.extractall(path=wt_dir)
            self.pretrained_weights = os.path.join(wt_dir,'resnet_v2_fp32_savedmodel_NHWC','1538687283','variables','variables')
        else:
            url = 'http://download.tensorflow.org/models/resnet_v1_50_2016_08_28.tar.gz'
            script_dir = os.path.dirname(os.path.realpath(__file__))
            wt_dir = os.path.join(script_dir,'pretrained')
            wt_file = os.path.join(wt_dir,'resnet_v1_50.ckpt')
            if not os.path.exists(wt_file):
                print('Downloading pretrained weights..')
                if not os.path.exists(wt_dir):
                    os.makedirs(wt_dir)
                sname, header = urllib.urlretrieve(url)
                tar = tarfile.open(sname, "r:gz")
                print('Extracting pretrained weights..')
                tar.extractall(path=wt_dir)
            self.pretrained_weights = os.path.join(wt_dir,'resnet_v1_50.ckpt')



    def create_network(self):

        im, locs, info, hmap = self.inputs
        conf = self.conf
        im.set_shape([conf.batch_size, conf.imsz[0]/conf.rescale,conf.imsz[1]/conf.rescale, conf.img_dim])
        hmap.set_shape([conf.batch_size, conf.imsz[0]/conf.rescale, conf.imsz[1]/conf.rescale,conf.n_classes])
        locs.set_shape([conf.batch_size, conf.n_classes,2])
        info.set_shape([conf.batch_size,3])
        if conf.img_dim == 1:
            im = tf.tile(im,[1,1,1,3])

        conv = lambda a, b: conv_relu3(
            a,b,self.ph['phase_train'], keep_prob=None,
            use_leaky=self.conf.unet_use_leaky)


        if self.resnet_source == 'slim':
            with slim.arg_scope(resnet_v1.resnet_arg_scope()):
                net, end_points = resnet_v1.resnet_v1_50(im,
                                          global_pool=False, is_training=self.ph[
                                          'phase_train'])
                l_names = ['conv1', 'block1/unit_2/bottleneck_v1', 'block2/unit_3/bottleneck_v1',
                           'block3/unit_5/bottleneck_v1', 'block4']
                down_layers = [end_points['resnet_v1_50/' + x] for x in l_names]

                ex_down_layers = conv(self.inputs[0], 64)
                down_layers.insert(0, ex_down_layers)
                n_filts = [32, 64, 64, 128, 256, 512]

        elif self.resnet_source == 'official_tf':
            mm = resnet_official.Model( resnet_size=50, bottleneck=True, num_classes=17, num_filters=32, kernel_size=7, conv_stride=2, first_pool_size=3, first_pool_stride=2, block_sizes=[3, 4, 6, 3], block_strides=[2, 2, 2, 2], final_size=2048, resnet_version=2, data_format='channels_last',dtype=tf.float32)
            im = tf.placeholder(tf.float32, [8, 512, 512, 3])
            resnet_out = mm(im, True)
            down_layers = mm.layers
            ex_down_layers = conv(self.inputs[0], 64)
            down_layers.insert(0, ex_down_layers)
            n_filts = [32, 64, 64, 128, 256, 512, 1024]


        with tf.variable_scope(self.net_name):

            prev_in = None
            for ndx in reversed(range(len(down_layers))):

                if prev_in is None:
                    X = down_layers[ndx]
                else:
                    X = tf.concat([prev_in, down_layers[ndx]],axis=-1)

                sc_name = 'layerup_{}_0'.format(ndx)
                with tf.variable_scope(sc_name):
                    X = conv(X, n_filts[ndx])

                if ndx is not 0:
                    sc_name = 'layerup_{}_1'.format(ndx)
                    with tf.variable_scope(sc_name):
                        X = conv(X, n_filts[ndx])

                    layers_sz = down_layers[ndx-1].get_shape().as_list()[1:3]
                    with tf.variable_scope('u_{}'.format(ndx)):
                        X = CNB.upscale('u_{}'.format(ndx), X, layers_sz)
                        # X_sh = X.get_shape().as_list()
                        # w_mat = np.zeros([5,5,X_sh[-1],X_sh[-1]])
                        # for wndx in range(X_sh[-1]):
                        #     w_mat[:,:,wndx,wndx] = 1.
                        # w = tf.get_variable('w', [5, 5, X_sh[-1], X_sh[-1]],initializer=tf.constant_initializer(w_mat))
                        # out_shape = [X_sh[0],layers_sz[0],layers_sz[1],X_sh[-1]]
                        # X = tf.nn.conv2d_transpose(X, w, output_shape=out_shape, strides=[1, 2, 2, 1], padding="SAME")
                        # biases = tf.get_variable('biases', [out_shape[-1]], initializer=tf.constant_initializer(0))
                        # conv_b = X + biases
                        #
                        # bn = batch_norm(conv_b)
                        # X = tf.nn.relu(bn)

                prev_in = X

            n_filt = X.get_shape().as_list()[-1]
            n_out = self.conf.n_classes
            weights = tf.get_variable("out_weights", [3,3,n_filt,n_out],
                                      initializer=tf.contrib.layers.xavier_initializer())
            biases = tf.get_variable("out_biases", n_out,
                                     initializer=tf.constant_initializer(0.))
            conv = tf.nn.conv2d(X, weights, strides=[1, 1, 1, 1], padding='SAME')
            X = tf.add(conv, biases, name = 'unet_pred')
            X = 2*tf.sigmoid(X)-1
        # X = conv+biases
        return X


    def get_var_list(self):
        var_list = tf.global_variables(self.net_name)
        for dep_net in self.dep_nets:
            var_list += dep_net.get_var_list()
        var_list += tf.global_variables('resnet_')
        return var_list

    def get_pred_fn(self, model_file=None):
        sess, latest_model_file = self.restore_net(model_file)
        conf = self.conf

        def pred_fn(all_f):
            # this is the function that is used for classification.
            # this should take in an array B x H x W x C of images, and
            # output an array of predicted locations.
            # predicted locations should be B x N x 2
            # PoseTools.get_pred_locs can be used to convert heatmaps into locations.

            bsize = conf.batch_size
            xs, _ = PoseTools.preprocess_ims(
                all_f, in_locs=np.zeros([bsize, self.conf.n_classes, 2]), conf=self.conf,
                distort=False, scale=self.conf.rescale)

            self.fd[self.inputs[0]] = xs
            self.fd[self.ph['phase_train']] = False
            self.fd[self.ph['learning_rate']] = 0
            # self.fd[self.ph['keep_prob']] = 1.

            pred, cur_input = sess.run([self.pred, self.inputs], self.fd)

            base_locs = PoseTools.get_pred_locs(pred)
            base_locs = base_locs * conf.rescale * self.out_scale

            ret_dict = {}
            ret_dict['locs'] = base_locs
            ret_dict['hmaps'] = pred
            ret_dict['conf'] = (np.max(pred,axis=(1,2)) + 1)/2
            return ret_dict

        def close_fn():
            sess.close()

        return pred_fn, close_fn, latest_model_file


class PoseUMDN_resnet(PoseUMDN.PoseUMDN):

    def __init__(self, conf, name='umdn_resnet',pad_input=False):
        conf.use_pretrained_weights = True
#        conf.pretrained_weights = '/home/mayank/work/deepcut/pose-tensorflow/models/pretrained/resnet_v1_50.ckpt'
        self.conf = conf
        # self.resnet_source = 'official_tf'
        self.resnet_source = self.conf.get('mdn_resnet_source','slim')
        self.offset = float(self.conf.get('mdn_slim_output_stride',32))
        PoseUMDN.PoseUMDN.__init__(self, conf, name=name,pad_input=pad_input)
        self.dep_nets = []
        self.max_dist = 30
        self.min_dist = 5

        #download pretrained weights if they don't exist
        if self.resnet_source == 'official_tf':
            url = 'http://download.tensorflow.org/models/official/20181001_resnet/savedmodels/resnet_v2_fp32_savedmodel_NHWC.tar.gz'
            script_dir = os.path.dirname(os.path.realpath(__file__))
            wt_dir = os.path.join(script_dir,'pretrained')
            wt_file = os.path.join(wt_dir,'resnet_v2_fp32_savedmodel_NHWC','1538687283','variables','variables.index')
            if not os.path.exists(wt_file):
                print('Downloading pretrained weights..')
                if not os.path.exists(wt_dir):
                    os.makedirs(wt_dir)
                sname, header = urllib.urlretrieve(url)
                tar = tarfile.open(sname, "r:gz")
                print('Extracting pretrained weights..')
                tar.extractall(path=wt_dir)
            self.pretrained_weights = os.path.join(wt_dir,'resnet_v2_fp32_savedmodel_NHWC','1538687283','variables','variables')
        else:
            url = 'http://download.tensorflow.org/models/resnet_v1_50_2016_08_28.tar.gz'
            script_dir = os.path.dirname(os.path.realpath(__file__))
            wt_dir = os.path.join(script_dir,'pretrained')
            wt_file = os.path.join(wt_dir,'resnet_v1_50.ckpt')
            if not os.path.exists(wt_file):
                print('Downloading pretrained weights..')
                if not os.path.exists(wt_dir):
                    os.makedirs(wt_dir)
                sname, header = urllib.urlretrieve(url)
                tar = tarfile.open(sname, "r:gz")
                print('Extracting pretrained weights..')
                tar.extractall(path=wt_dir)
            self.pretrained_weights = os.path.join(wt_dir,'resnet_v1_50.ckpt')

            # self.pretrained_weights = '/home/mayank/work/poseTF/deepcut/models/resnet_v1_50.ckpt'

    def create_network(self):

        im, locs, info, hmap = self.inputs
        conf = self.conf
        in_sz = [int(sz//conf.rescale) for sz in conf.imsz]
        im.set_shape([conf.batch_size,
                      in_sz[0] + self.pad_y,
                      in_sz[1] + self.pad_x,
                      conf.img_dim])
        hmap.set_shape([conf.batch_size, in_sz[0], in_sz[1],conf.n_classes])
        locs.set_shape([conf.batch_size, conf.n_classes,2])
        info.set_shape([conf.batch_size,3])
        if conf.img_dim == 1:
            im = tf.tile(im,[1,1,1,3])

        conv = lambda a, b: conv_relu3(
            a,b,self.ph['phase_train'], keep_prob=None,
            use_leaky=self.conf.unet_use_leaky)

        def conv_nopad(x_in,n_filt):
            in_dim = x_in.get_shape().as_list()[3]
            kernel_shape = [3, 3, in_dim, n_filt]
            weights = tf.get_variable("weights", kernel_shape,
                                      initializer=tf.contrib.layers.xavier_initializer())
            biases = tf.get_variable("biases", kernel_shape[-1],
                                     initializer=tf.constant_initializer(0.))
            conv = tf.nn.conv2d(x_in, weights, strides=[1, 1, 1, 1], padding='VALID')
            conv = batch_norm(conv, decay=0.99, is_training=self.ph['phase_train'])

            if self.conf.unet_use_leaky:
                return tf.nn.leaky_relu(conv + biases)
            else:
                return tf.nn.relu(conv + biases)

        if self.resnet_source == 'slim':
            with slim.arg_scope(resnet_v1.resnet_arg_scope()):
                if self.conf.get('mdn_slim_is_training',True):
                    slim_is_training = self.ph['phase_train']
                else:
                    slim_is_training = False

                output_stride =  self.conf.get('mdn_slim_output_stride',None)

                net, end_points = resnet_v1.resnet_v1_50(im,global_pool=False, is_training=slim_is_training,output_stride=output_stride)
                l_names = ['conv1', 'block1/unit_2/bottleneck_v1', 'block2/unit_3/bottleneck_v1',
                           'block3/unit_5/bottleneck_v1']
                if not self.no_pad: l_names.append('block4')
                down_layers = [end_points['resnet_v1_50/' + x] for x in l_names]

                # n_filts = [64, 64, 64, 128, 256, 512]
                n_filts = [32, 64, 128, 256, 512, 1024]

        elif self.resnet_source == 'official_tf':
            mm = resnet_official.Model(resnet_size=50, bottleneck=True, num_classes=17, num_filters=64, kernel_size=7,
                                       conv_stride=2, first_pool_size=3, first_pool_stride=2, block_sizes=[3, 4, 6, 3],
                                       block_strides=[1, 2, 2, 2], final_size=2048, resnet_version=2,
                                       data_format='channels_last', dtype=tf.float32)
            resnet_out = mm(im, self.ph['phase_train'])
            down_layers = mm.layers
            down_layers.pop(2) # remove one of the layers of size imsz/4, imsz/4 at index 2
            net = down_layers[-1]
            n_filts = [32, 64, 64, 128, 256, 512, 1024]
            # n_filts = [ 64, 64, 128, 256, 512, 1024]

        if self.conf.mdn_use_unet_loss:
            with tf.variable_scope(self.net_name + '_unet'):

                # add an extra layer at input resolution.
                # ex_down_layers = conv(im, 32)
                # down_layers.insert(0, ex_down_layers)

                prev_in = None
                for ndx in reversed(range(len(down_layers))):

                    if prev_in is None:
                        X = down_layers[ndx]
                    else:
                        if self.no_pad:
                            prev_sh = prev_in.get_shape().as_list()[1:3]
                            d_sh = down_layers[ndx].get_shape().as_list()[1:3]
                            d_y = (d_sh[0]- prev_sh[0])//2
                            d_x = (d_sh[1]- prev_sh[1])//2
                            d_l = down_layers[ndx][:,d_y:(prev_sh[0]+d_y),d_x:(prev_sh[1]+d_x),:]
                            X = tf.concat([prev_in, d_l], axis=-1)
                        else:
                            X = tf.concat([prev_in, down_layers[ndx]],axis=-1)

                    sc_name = 'layerup_{}_0'.format(ndx)
                    with tf.variable_scope(sc_name):
                        if self.no_pad:
                            X = conv_nopad(X, n_filts[ndx])
                        else:
                            X = conv(X, n_filts[ndx])

                    if ndx is not -1:
                        sc_name = 'layerup_{}_1'.format(ndx)
                        with tf.variable_scope(sc_name):
                            if self.no_pad:
                                X = conv_nopad(X, n_filts[ndx])
                            else:
                                X = conv(X, n_filts[ndx])

                        if ndx > 0:
                            layers_sz = down_layers[ndx-1].get_shape().as_list()[1:3]
                        else:
                            layers_sz = in_sz

                        with tf.variable_scope('u_{}'.format(ndx)):
                             # X = CNB.upscale('u_{}'.format(ndx), X, layers_sz)
                           X_sh = X.get_shape().as_list()
                           w_mat = np.zeros([4,4,X_sh[-1],X_sh[-1]])
                           for wndx in range(X_sh[-1]):
                               w_mat[:,:,wndx,wndx] = 1.
                           w = tf.get_variable('w', [4, 4, X_sh[-1], X_sh[-1]],initializer=tf.constant_initializer(w_mat))
                           if self.no_pad:
                               out_shape = [X_sh[0],X_sh[1]*2+2,X_sh[2]*2+2,X_sh[-1]]
                               X = tf.nn.conv2d_transpose(X, w, output_shape=out_shape,
                                                          strides=[1, 2, 2, 1], padding="VALID")
                           else:
                               out_shape = [X_sh[0],layers_sz[0],layers_sz[1],X_sh[-1]]
                               X = tf.nn.conv2d_transpose(X, w, output_shape=out_shape,
                                                          strides=[1, 2, 2, 1], padding="SAME")
                           biases = tf.get_variable('biases', [out_shape[-1]], initializer=tf.constant_initializer(0))
                           conv_b = X + biases

                           bn = batch_norm(conv_b)
                           X = tf.nn.relu(bn)

                    prev_in = X

                n_filt = X.get_shape().as_list()[-1]
                n_out = self.conf.n_classes
                weights = tf.get_variable("out_weights", [3,3,n_filt,n_out],
                                          initializer=tf.contrib.layers.xavier_initializer())
                biases = tf.get_variable("out_biases", n_out,
                                         initializer=tf.constant_initializer(0.))
                conv_out = tf.nn.conv2d(X, weights, strides=[1, 1, 1, 1], padding='SAME')
                X = tf.add(conv_out, biases, name = 'unet_pred')
                X_unet = 2*tf.sigmoid(X)-1
                if self.no_pad:
                    unet_sh = X_unet.get_shape().as_list()[1:3]
                    out_sz = [y//self.conf.rescale for y in self.conf.imsz]
                    crop_x = (unet_sh[1] - out_sz[1])//2
                    crop_y = (unet_sh[0] - out_sz[0])//2
                    X_unet = X_unet[:, crop_y:(crop_y + out_sz[0]), crop_x:(crop_x+out_sz[1]),:]

            self.unet_pred = X_unet

        X = net
        k = 2
        locs_offset = 1.
        n_groups = len(self.conf.mdn_groups)
        n_out = self.conf.n_classes
        # self.offset = float(self.conf.imsz[0])/X.get_shape().as_list()[1]

        with tf.variable_scope(self.net_name):
            if self.conf.get('mdn_regularize_wt',False) is True:
                wt_scale = self.conf.get('mdn_regularize_wt_scale',0.1)
                wt_reg = tf.contrib.layers.l2_regularizer(scale=wt_scale)
            else:
                wt_reg = None

            n_filt_in = X.get_shape().as_list()[3]
            n_filt = 512
            k_sz = 3
            with tf.variable_scope('locs'):
                with tf.variable_scope('layer_locs'):
                    kernel_shape = [k_sz, k_sz, n_filt_in, 3*n_filt]
                    mdn_l = conv_relu(X,kernel_shape,self.ph['phase_train'])

                explicit_offset = self.conf.get('mdn_explicit_offset',True)
                    
                if self.conf.get('mdn_more_locs_layer',True):
                    with tf.variable_scope('layer_locs_1_1'):
                        in_filt = mdn_l.get_shape().as_list()[3]
                        kernel_shape = [k_sz, k_sz, in_filt, n_filt]
                        mdn_l = conv_relu(mdn_l,kernel_shape, self.ph['phase_train'])

                else:
                
                    with tf.variable_scope('layer_locs_1_1'):
                        in_filt = mdn_l.get_shape().as_list()[3]
                        kernel_shape = [k_sz, k_sz, in_filt, 2*n_filt]
                        mdn_l = conv_relu(mdn_l,kernel_shape, self.ph['phase_train'])
                        mdn_l_1 = mdn_l
                    # more layers are sometimes required for implicit offsets
                    with tf.variable_scope('layer_locs_1_2'):
                        in_filt = mdn_l.get_shape().as_list()[3]
                        kernel_shape = [k_sz, k_sz, in_filt, 2*n_filt]
                        mdn_l = conv_relu(mdn_l,kernel_shape, self.ph['phase_train'])

                    with tf.variable_scope('layer_locs_1_3'):
                        in_filt = mdn_l.get_shape().as_list()[3]
                        kernel_shape = [k_sz, k_sz, in_filt, 2*n_filt]
                        mdn_l = conv_relu(mdn_l,kernel_shape, self.ph['phase_train'])

                    mdn_l = mdn_l + mdn_l_1 # skip connection

                    with tf.variable_scope('layer_locs_2'):
                        in_filt = mdn_l.get_shape().as_list()[3]
                        kernel_shape = [k_sz, k_sz, in_filt, n_filt*2]
                        mdn_l = conv_relu(mdn_l,kernel_shape, self.ph['phase_train'])

                    with tf.variable_scope('layer_locs_3'):
                        in_filt = mdn_l.get_shape().as_list()[3]
                        kernel_shape = [k_sz, k_sz, in_filt, n_filt]
                        mdn_l = conv_relu(mdn_l,kernel_shape, self.ph['phase_train'])

                loc_shape = mdn_l.get_shape().as_list()
                n_x = loc_shape[2]
                n_y = loc_shape[1]
                x_off, y_off = np.meshgrid(np.arange(n_x), np.arange(n_y))
                x_off = np.tile(x_off[np.newaxis,:,:,np.newaxis],[loc_shape[0],1,1,1])
                y_off = np.tile(y_off[np.newaxis,:,:,np.newaxis], [loc_shape[0],1,1,1])


                if explicit_offset:
                    # o_locs = ((tf.sigmoid(o_locs) * 2) - 0.5) * locs_offset
                    weights_locs = tf.get_variable("weights_locs", [1, 1, n_filt, 2 * k * n_out],                                              initializer=tf.contrib.layers.xavier_initializer(),regularizer=wt_reg)
                    biases_locs = tf.get_variable("biases_locs", 2 * k * n_out,
                                                  initializer=tf.constant_initializer(0))
                    o_locs = tf.nn.conv2d(mdn_l, weights_locs,
                                          [1, 1, 1, 1], padding='SAME') + biases_locs
                    locs = tf.reshape(o_locs, [-1, n_x * n_y * k, n_out, 2], name='locs_final')
                    o_locs = tf.reshape(o_locs,[-1,n_y,n_x,k,n_out,2])
                    self.i_locs = o_locs
                    o_locs *= float(locs_offset)
                    o_locs += float(locs_offset)/2

                    # adding offset of each grid location.
                    x_off = x_off * locs_offset
                    y_off = y_off * locs_offset
                    x_off = x_off[..., np.newaxis]
                    y_off = y_off[..., np.newaxis]
                    x_locs = o_locs[:, :, :, :, :, 0] + x_off
                    y_locs = o_locs[:, :, :, :, :, 1] + y_off
                    o_locs = tf.stack([x_locs, y_locs], axis=5)
                    locs = tf.reshape(o_locs, [-1, n_x * n_y * k, n_out, 2], name='locs_final')
                else:
                    mdn_l = tf.concat([mdn_l,x_off,y_off],axis=-1)
                    weights_locs = tf.get_variable("weights_locs", [1, 1, n_filt+2, 2 * k * n_out],                                              initializer=tf.contrib.layers.xavier_initializer(),regularizer=wt_reg)
                    biases_locs = tf.get_variable("biases_locs", 2 * k * n_out,
                                                  initializer=tf.constant_initializer(0))
                    o_locs = tf.nn.conv2d(mdn_l, weights_locs,
                                          [1, 1, 1, 1], padding='SAME') + biases_locs
                    locs = tf.reshape(o_locs, [-1, n_x * n_y * k, n_out, 2], name='locs_final')

            with tf.variable_scope('scales'):
                with tf.variable_scope('layer_scales'):
                    kernel_shape = [1, 1, n_filt_in, n_filt]
                    weights = tf.get_variable("weights", kernel_shape,
                                              initializer=tf.contrib.layers.xavier_initializer(),regularizer=wt_reg)
                    biases = tf.get_variable("biases", kernel_shape[-1],
                                             initializer=tf.constant_initializer(0))
                    conv = tf.nn.conv2d(X, weights,
                                        strides=[1, 1, 1, 1], padding='SAME')
                    conv = batch_norm(conv, decay=0.99,
                                      is_training=self.ph['phase_train'])
                mdn_l = tf.nn.relu(conv + biases)

                weights_scales = tf.get_variable("weights_scales", [1, 1, n_filt, k * n_out],
                                                 initializer=tf.contrib.layers.xavier_initializer(),regularizer=wt_reg)
                biases_scales = tf.get_variable("biases_scales", k * self.conf.n_classes,
                                                initializer=tf.constant_initializer(0))
                o_scales = tf.exp(tf.nn.conv2d(mdn_l, weights_scales,
                                               [1, 1, 1, 1], padding='SAME') + biases_scales)
                # when initialized o_scales will be centered around exp(0) and
                # mostly between [exp(-1), exp(1)] = [0.3 2.7]
                # so adding appropriate offsets to make it lie between the wanted range
                min_sig = self.conf.mdn_min_sigma
                max_sig = self.conf.mdn_max_sigma
                o_scales = (o_scales - 1) * (max_sig - min_sig) / 2
                o_scales = o_scales + (max_sig - min_sig) / 2 + min_sig
                scales = tf.minimum(max_sig, tf.maximum(min_sig, o_scales))
                scales = tf.reshape(scales, [-1, n_x * n_y, k, n_out])
                scales = tf.reshape(scales, [-1, n_x * n_y * k, n_out], name='scales_final')

            with tf.variable_scope('logits'):
                with tf.variable_scope('layer_logits'):
                    kernel_shape = [1, 1, n_filt_in, n_filt]
                    weights = tf.get_variable("weights", kernel_shape,
                                              initializer=tf.contrib.layers.xavier_initializer(),regularizer=wt_reg)
                    biases = tf.get_variable("biases", kernel_shape[-1],
                                             initializer=tf.constant_initializer(0))
                    conv = tf.nn.conv2d(X, weights,
                                        strides=[1, 1, 1, 1], padding='SAME')
                    conv = batch_norm(conv, decay=0.99,
                                      is_training=self.ph['phase_train'])
                mdn_l = tf.nn.relu(conv + biases)

                weights_logits = tf.get_variable("weights_logits", [1, 1, n_filt, k * n_groups],
                                                 initializer=tf.contrib.layers.xavier_initializer())
                biases_logits = tf.get_variable("biases_logits", k * n_groups,
                                                initializer=tf.constant_initializer(0))
                logits = tf.nn.conv2d(mdn_l, weights_logits,
                                      [1, 1, 1, 1], padding='SAME') + biases_logits

                # blur_weights
                # self.logits_pre_blur = logits
                # # blur the weights during training.
                # blur_rad = 2.5 #0.7
                # filt_sz = np.ceil(blur_rad * 3).astype('int')
                # xx, yy = np.meshgrid(np.arange(-filt_sz, filt_sz + 1), np.arange(-filt_sz, filt_sz + 1))
                # gg = stats.norm.pdf(np.sqrt(xx ** 2 + yy ** 2)/blur_rad)
                # gg = gg/gg.sum()
                # blur_kernel = np.tile(gg[:,:,np.newaxis,np.newaxis],[1,1,k*n_groups, k*n_groups])
                # logits_blur = tf.nn.conv2d(logits, blur_kernel,[1,1,1,1], padding='SAME')
                # # blur_weights_extra
                # logits = tf.cond(self.ph['phase_train'], lambda: tf.identity(logits_blur), lambda: tf.identity(logits))
                # logits = logits_blur

                logits = tf.reshape(logits, [-1, n_x * n_y, k * n_groups])
                logits = tf.reshape(logits, [-1, n_x * n_y * k, n_groups], name='logits_final')

            with tf.variable_scope('dist'):
                X_dist = tf.stop_gradient(X)
                with tf.variable_scope('layer_dist'):
                    kernel_shape = [1, 1, n_filt_in, n_filt]
                    weights = tf.get_variable("weights", kernel_shape,
                                              initializer=tf.contrib.layers.xavier_initializer(),regularizer=wt_reg)
                    biases = tf.get_variable("biases", kernel_shape[-1],
                                             initializer=tf.constant_initializer(0))
                    conv = tf.nn.conv2d(X_dist, weights,
                                        strides=[1, 1, 1, 1], padding='SAME')
                    conv = batch_norm(conv, decay=0.99,
                                      is_training=self.ph['phase_train'])
                mdn_l = tf.nn.relu(conv + biases)

                weights_dist = tf.get_variable("weights_dist", [1, 1, n_filt, k * n_out],
                                                 initializer=tf.contrib.layers.xavier_initializer())
                biases_dist = tf.get_variable("biases_dist", k * self.conf.n_classes,
                                                initializer=tf.constant_initializer(0))
                o_dist = tf.sigmoid(tf.nn.conv2d(mdn_l, weights_dist,
                                               [1, 1, 1, 1], padding='SAME') + biases_dist)
                dist = self.max_dist*o_dist
                dist = tf.reshape(dist, [-1, n_x * n_y, k, n_out])
                dist = tf.reshape(dist, [-1, n_x * n_y * k, n_out], name='dist_final')

            return [locs, scales, logits, dist]


    def get_var_list(self):
        var_list = tf.global_variables(self.net_name)
        var_list += tf.global_variables('resnet_')
        return var_list



    def train_umdn(self, restore=False):

        self.joint = True

        learning_rate = self.conf.get('mdn_learning_rate',0.0001)
        super(self.__class__, self).train(
            create_network=self.create_network,
            loss=self.loss,
            learning_rate=learning_rate,restore=restore)

    def loss(self, inputs, pred):
        in_locs = inputs[1]
        # mdn_loss = self.my_loss(pred, inputs[1])
        mdn_loss = self.l2_loss(pred, in_locs)
        if self.conf.mdn_use_unet_loss:
            # unet_loss = tf.losses.mean_squared_error(inputs[-1], self.unet_pred)
            unet_loss = tf.sqrt(
                tf.nn.l2_loss(inputs[-1] - self.unet_pred)) / self.conf.label_blur_rad / self.conf.n_classes
        else:
            unet_loss = 0

        if self.conf.mdn_pred_dist:
            dist_loss = self.dist_loss() / 10
        else:
            dist_loss = 0

        # wt regularization loss
        regularizer_losses = tf.get_collection(tf.GraphKeys.REGULARIZATION_LOSSES)

        return (mdn_loss + unet_loss + dist_loss + sum(regularizer_losses)) / self.conf.batch_size

    def my_loss(self, X, y):

        locs_offset = self.offset

        mdn_locs, mdn_scales, mdn_logits, mdn_dist = X
        cur_comp = []
        ll = tf.nn.softmax(mdn_logits, axis=1)

        n_preds = mdn_locs.get_shape().as_list()[1]
        # All gaussians in the mixture have some weight so that all the mixtures try to predict correctly.
        logit_eps = self.conf.mdn_logit_eps_training
        # ll = tf.cond(self.ph['phase_train'], lambda: ll + logit_eps, lambda: tf.identity(ll))
        ll = ll / tf.reduce_sum(ll, axis=1, keepdims=True)
        for cls in range(self.conf.n_classes):
            cur_scales = mdn_scales[:, :, cls]
            pp = y[:, cls:cls + 1, :]/locs_offset
            kk = tf.sqrt(tf.reduce_sum(tf.square(pp - mdn_locs[:, :, cls, :]), axis=2))
            # tf.div is actual correct implementation of gaussian distance.
            # but we run into numerical issues. Since the scales are withing
            # the same range, I'm just ignoring them for now.
            # dd = tf.div(tf.exp(-kk / (cur_scales ** 2) / 2), 2 * np.pi * (cur_scales ** 2))
            dd = tf.exp(-kk / cur_scales / 2)
            cur_comp.append(dd)

        for ndx,gr in enumerate(self.conf.mdn_groups):
            sel_comp = [cur_comp[i] for i in gr]
            sel_comp = tf.stack(sel_comp, 1)
            pp = ll[:,:, ndx] * \
                       tf.reduce_prod(sel_comp, axis=1) + 1e-30
            if ndx is 0:
                cur_loss = -tf.log(tf.reduce_sum(pp,axis=1))
            else:
                cur_loss = cur_loss - tf.log(tf.reduce_sum(pp,axis=1))

        # product because we are looking at joint distribution of all the points.
        # pp = cur_loss + 1e-30
        # loss = -tf.log(tf.reduce_sum(pp, axis=1))
        return tf.reduce_sum(cur_loss)/self.conf.n_classes

    def l2_loss(self, X, y):

        locs_offset = self.offset
        mdn_locs, mdn_scales, mdn_logits, mdn_dist = X
        cur_comp = []
        ll = tf.nn.softmax(mdn_logits, axis=1)

        n_preds = mdn_locs.get_shape().as_list()[1]
        # All gaussians in the mixture have some weight so that all the mixtures try to predict correctly.
        logit_eps = self.conf.mdn_logit_eps_training
        ll = tf.cond(self.ph['phase_train'], lambda: ll + logit_eps, lambda: tf.identity(ll))
        ll = ll / tf.reduce_sum(ll, axis=1, keepdims=True)
        # ll now has normalized logits.
        for cls in range(self.conf.n_classes):
            pp = y[:, cls:cls + 1, :]/locs_offset
            kk = tf.sqrt(tf.reduce_sum(tf.square(pp - mdn_locs[:, :, cls, :]), axis=2))
            # kk is the distance between all predictions for point cls from the labels.
            cur_comp.append(kk)

        cur_loss = 0
        for ndx,gr in enumerate(self.conf.mdn_groups):
            sel_comp = [cur_comp[i] for i in gr]
            sel_comp = tf.stack(sel_comp, 1)
            pp = ll[:,:, ndx] * tf.reduce_sum(sel_comp, axis=1)
            cur_loss += pp

        return tf.reduce_sum(cur_loss)/self.conf.n_classes


    def dist_loss(self):

        locs_offset = self.offset
        mdn_locs, mdn_scales, mdn_logits, mdn_dist = self.pred
        y = self.inputs[1]

        cur_comp = []

        ll = tf.nn.softmax(mdn_logits, axis=1)
#         logit_eps = self.conf.mdn_logit_eps_training
#         ll = tf.cond(self.ph['phase_train'], lambda: ll + logit_eps, lambda: tf.identity(ll))
#         ll = ll / tf.reduce_sum(ll, axis=1, keepdims=True)

        ll = tf.stop_gradient(ll)
        # ll now has normalized logits.
        for cls in range(self.conf.n_classes):
            pp = y[:, cls:cls + 1, :]/locs_offset
            kk = tf.sqrt(tf.reduce_sum(tf.square(pp - mdn_locs[:, :, cls, :]), axis=2))
            # kk is the distance between all predictions for point cls from the labels.
            kk = tf.clip_by_value(kk-self.min_dist/locs_offset/self.conf.rescale,0,self.max_dist/locs_offset/self.conf.rescale)
            kk = tf.stop_gradient(kk)
            dd = tf.abs(kk-mdn_dist[:,:,cls])
            cur_comp.append(dd)

        cur_loss = 0
        for ndx,gr in enumerate(self.conf.mdn_groups):
            sel_comp = [cur_comp[i] for i in gr]
            sel_comp = tf.stack(sel_comp, 1)
            # pp = ll[:,:, ndx] * tf.reduce_sum(sel_comp, axis=1)
            pp = ll[:,:, ndx] * tf.reduce_sum(sel_comp, axis=1)
            cur_loss += pp

        return tf.reduce_sum(cur_loss)/self.conf.n_classes


    def compute_dist(self, preds, locs):

        locs_offset = self.offset

        locs = locs.copy()
        if locs.ndim == 3:
            locs = locs[:,np.newaxis,:,:]
        val_means, val_std, val_wts = preds
        val_means = val_means * locs_offset
        val_dist = np.zeros(locs.shape[:-1])
        pred_dist = np.zeros(val_means.shape[:-1])
        pred_dist[:] = np.nan
        for ndx in range(val_means.shape[0]):
            for gdx, gr in enumerate(self.conf.mdn_groups):
                for g in gr:
                    if locs.shape[1] == 1:
                        sel_ex = (np.argmax(val_wts[ndx,:,gdx]),)
                    else:
                        sel_ex = val_wts[ndx, :, gdx] > 0
                    mm = val_means[ndx, ...][np.newaxis, sel_ex, :, :]
                    ll = locs[ndx, ...][:, np.newaxis, :, :]
                    jj =  mm[:,:,g,:] - ll[:,:,g,:]
                    # jj has distance between all labels and
                    # all predictions with wts > 0.
                    dd1 = np.sqrt(np.sum(jj ** 2, axis=-1)).min(axis=1)
                    # instead of min it should ideally be matching.
                    # but for now this is ok.
                    dd2 = np.sqrt(np.sum(jj ** 2, axis=-1)).min(axis=0)
                    # dd1 -- to every label is there a close by prediction.
                    # dd2 -- to every prediction is there a close by labels.
                    # or dd1 is fn and dd2 is fp.
                    val_dist[ndx,:, g] = dd1 * self.conf.rescale
                    pred_dist[ndx,sel_ex, g] = dd2 * self.conf.rescale
        val_dist[locs[..., 0] < -5000] = np.nan
        pred_mean = np.nanmean(pred_dist)
        label_mean = np.nanmean(val_dist)
        return (pred_mean+label_mean)/2


    def get_pred_fn(self, model_file=None):
        sess, latest_model_file = self.restore_net(model_file)

        conf = self.conf

        mdn_unet_dist = self.conf.get('mdn_unet_dist',6)

        def pred_fn(all_f):
            # this is the function that is used for classification.
            # this should take in an array B x H x W x C of images, and
            # output an array of predicted locations.
            # predicted locations should be B x N x 2
            # PoseTools.get_pred_locs can be used to convert heatmaps into locations.

            bsize = conf.batch_size
            xs, _ = PoseTools.preprocess_ims(
                all_f, in_locs=np.zeros([bsize, self.conf.n_classes, 2]), conf=self.conf,
                distort=False, scale=self.conf.rescale)

            self.fd[self.inputs[0]] = xs
            self.fd[self.ph['phase_train']] = False
            self.fd[self.ph['learning_rate']] = 0
            # self.fd[self.ph['keep_prob']] = 1.

            if self.conf.mdn_use_unet_loss:
                pred, unet_pred, cur_input = sess.run([self.pred, self.unet_pred, self.inputs], self.fd)
            else:
                pred, cur_input = sess.run([self.pred, self.inputs], self.fd)

            pred_means, pred_std, pred_weights,pred_dist = pred
            pred_means = pred_means * self.offset
            pred_weights = PoseUMDN.softmax(pred_weights,axis=1)

            osz = [int(i/conf.rescale) for i in self.conf.imsz]
            mdn_pred_out = np.zeros([bsize, osz[0], osz[1], conf.n_classes])

            # for sel in range(bsize):
            #     for cls in range(conf.n_classes):
            #         for ndx in range(pred_means.shape[1]):
            #             cur_gr = [l.count(cls) for l in self.conf.mdn_groups].index(1)
            #             if pred_weights[sel, ndx, cur_gr] < (0.02 / self.conf.max_n_animals):
            #                 continue
            #             cur_locs = np.round(pred_means[sel:sel + 1, ndx:ndx + 1, cls, :]).astype('int')
            #             # cur_scale = pred_std[sel, ndx, cls, :].mean().astype('int')
            #             cur_scale = pred_std[sel, ndx, cls].astype('int')
            #             curl = (PoseTools.create_label_images(cur_locs, osz, 1, cur_scale) + 1) / 2
            #             mdn_pred_out[sel, :, :, cls] += pred_weights[sel, ndx, cur_gr] * curl[0, ..., 0]
            #
            # base_locs = PoseTools.get_pred_locs(mdn_pred_out)
            base_locs = np.zeros([pred_means.shape[0],self.conf.n_classes,2])
            for ndx in range(pred_means.shape[0]):
                for gdx, gr in enumerate(self.conf.mdn_groups):
                    for g in gr:
                        sel_ex = np.argmax(pred_weights[ndx, :, gdx])
                        mm = pred_means[ndx, sel_ex, g, :]
                        base_locs[ndx, g] = mm

            base_locs = base_locs * conf.rescale

            mdn_pred_out = 2*(mdn_pred_out-0.5)
            unet_locs = PoseTools.get_pred_locs(unet_pred)
            if self.conf.mdn_use_unet_loss:
                d = np.sqrt(np.sum((base_locs - unet_locs) ** 2, axis=-1))
                mdn_unet_locs = base_locs
                mdn_unet_locs[d < mdn_unet_dist, :] = unet_locs[d < mdn_unet_dist, :]
            else:
                unet_pred = mdn_pred_out
                mdn_unet_locs = base_locs

            ret_dict = {}
            ret_dict['locs'] = mdn_unet_locs
            ret_dict['hmaps'] = unet_pred
            ret_dict['locs_mdn'] = base_locs
            ret_dict['locs_unet'] = unet_locs
            ret_dict['conf_unet'] = (np.max(unet_pred,axis=(1,2)) + 1)/2
            ret_dict['conf'] = np.max(mdn_pred_out,axis=(1,2))
            ret_dict['hmaps_mdn'] = mdn_pred_out
            return ret_dict

        def close_fn():
            sess.close()

        return pred_fn, close_fn, latest_model_file



    def classify_val(self, model_file=None, onTrain=False):
        if not onTrain:
            val_file = os.path.join(self.conf.cachedir, self.conf.valfilename + '.tfrecords')
        else:
            val_file = os.path.join(self.conf.cachedir, self.conf.trainfilename + '.tfrecords')

        num_val = 0
        for _ in tf.python_io.tf_record_iterator(val_file):
            num_val += 1

        print('--- Loading the model by reconstructing the graph ---')
        self.setup_train()
        self.pred = self.create_network()
        self.create_saver()
        sess = tf.Session()
        self.restore(sess, model_file)
        PoseCommon.initialize_remaining_vars(sess)

        try:
            self.restore_td()
        except AttributeError:  # If the conf file has been modified
            print("Couldn't load train data because the conf has changed!")
            self.init_td()

        p_m, p_s, p_w, p_d = self.pred
        conf = self.conf
        osz = list(self.conf.imsz)
        osz[0] += self.pad_y
        osz[1] += self.pad_x
        #       self.joint = True

        locs_offset = self.offset
        p_m *= locs_offset

        val_dist = []
        val_ims = []
        val_preds = []
        val_predlocs = []
        val_locs = []
        val_means = []
        val_std = []
        val_wts = []
        val_u_preds = []
        val_u_predlocs = []
        val_dist_pred = []
        for step in range(num_val / self.conf.batch_size):
            if onTrain:
                self.fd_train()
            else:
                self.fd_val()
            if self.conf.mdn_use_unet_loss:
                pred_means, pred_std, pred_weights, pred_dist, cur_input, unet_pred = sess.run(
                    [p_m, p_s, p_w, p_d, self.inputs, self.unet_pred], self.fd)
            else:
                pred_means, pred_std, pred_weights, pred_dist, cur_input = sess.run(
                    [p_m, p_s, p_w, p_d, self.inputs], self.fd)

            val_means.append(pred_means)
            val_std.append(pred_std)
            val_wts.append(pred_weights)
            val_dist_pred.append(pred_dist)
            pred_weights = PoseUMDN.softmax(pred_weights, axis=1)
            mdn_pred_out = np.zeros([self.conf.batch_size, osz[0], osz[1], conf.n_classes])

            locs = cur_input[1]
            cur_dist = np.zeros([conf.batch_size, conf.n_classes])
            cur_predlocs = np.zeros(pred_means.shape[0:1] + pred_means.shape[2:])
            #            for ndx in range(pred_means.shape[0]):
            #                for gdx, gr in enumerate(self.conf.mdn_groups):
            #                    for g in gr:
            #                        sel_ex = np.argmax(pred_weights[ndx,:,gdx])
            #                        mm = pred_means[ndx, sel_ex, g, :]
            #                        ll = locs[ndx,g,:]
            #                        jj =  mm-ll
            #                        # jj has distance between all labels and
            #                        # all predictions with wts > 0.
            #                        dd1 = np.sqrt(np.sum(jj ** 2, axis=-1))
            #                        cur_dist[ndx, g] = dd1 * self.conf.rescale
            #                        cur_predlocs[ndx,g,...] = mm
            for sel in range(conf.batch_size):
                for cls in range(conf.n_classes):
                    for ndx in range(pred_means.shape[1]):
                        cur_gr = [l.count(cls) for l in self.conf.mdn_groups].index(1)
                        if pred_weights[sel, ndx, cur_gr] < (0.02 / self.conf.max_n_animals):
                            continue
                        cur_locs = np.round(pred_means[sel:sel + 1, ndx:ndx + 1, cls, :]).astype('int')
                        cur_scale = pred_std[sel, ndx, cls].astype('int')
                        curl = (PoseTools.create_label_images(cur_locs, osz, 1, cur_scale) + 1) / 2
                        mdn_pred_out[sel, :, :, cls] += pred_weights[sel, ndx, cur_gr] * curl[0, ..., 0]

            locs = cur_input[1]
            if locs.ndim == 3:
                cur_predlocs = PoseTools.get_pred_locs(mdn_pred_out)
                cur_dist = np.sqrt(np.sum(
                    (cur_predlocs - locs / self.conf.unet_rescale) ** 2, 2))
            else:
                cur_predlocs = PoseTools.get_pred_locs_multi(
                    mdn_pred_out, self.conf.max_n_animals,
                    self.conf.label_blur_rad * 7)
                curl = locs.copy() / self.conf.unet_rescale
                jj = cur_predlocs[:, :, np.newaxis, :, :] - curl[:, np.newaxis, ...]
                cur_dist = np.sqrt(np.sum(jj ** 2, axis=-1)).min(axis=1)
            val_dist.append(cur_dist)
            val_ims.append(cur_input[0])
            val_locs.append(cur_input[1])
            val_preds.append(mdn_pred_out)
            val_predlocs.append(cur_predlocs)
            if self.conf.mdn_use_unet_loss:
                val_u_preds.append(unet_pred)
                val_u_predlocs.append(PoseTools.get_pred_locs(unet_pred))

        sess.close()

        def val_reshape(in_a):
            in_a = np.array(in_a)
            return in_a.reshape((-1,) + in_a.shape[2:])

        val_dist = val_reshape(val_dist)
        val_ims = val_reshape(val_ims)
        val_preds = val_reshape(val_preds)
        val_predlocs = val_reshape(val_predlocs)
        val_locs = val_reshape(val_locs)
        val_means = val_reshape(val_means)
        val_std = val_reshape(val_std)
        val_wts = val_reshape(val_wts)
        val_dist_pred = val_reshape(val_dist_pred)
        tf.reset_default_graph()
        if self.conf.mdn_use_unet_loss:
            val_u_preds = val_reshape(val_u_preds)
            val_u_predlocs = val_reshape(val_u_predlocs)
            return val_dist, val_ims, val_preds, val_predlocs, val_locs, \
               [val_means, val_std, val_wts, val_dist_pred],[val_u_preds, val_u_predlocs]
        else:
            return val_dist, val_ims, val_preds, val_predlocs, val_locs, \
               [val_means, val_std, val_wts, val_dist_pred]


def preproc_func(ims, locs, info, conf, distort, out_scale = 8.):

    ims, locs = PoseTools.preprocess_ims(ims, locs, conf, distort, conf.rescale)
    tlocs = locs.copy()
    osz0 = int(math.ceil(conf.imsz[0]/conf.rescale/(out_scale*2)))*2
    scale = float(conf.imsz[0])/osz0

    hmaps = PoseTools.create_label_images(tlocs, conf.imsz, scale, conf.label_blur_rad)
    return ims.astype('float32'), locs.astype('float32'), info.astype('float32'), hmaps.astype('float32')


class PoseUNet_resnet_lowres(PoseUNet_resnet):

    def __init__(self, conf, name='unet_resnet_lowres'):
        conf.use_pretrained_weights = True
        PoseUNet_resnet.__init__(self, conf, name=name)
        self.conf = conf
        self.output_stride = self.conf.get('mdn_slim_output_stride', 16)
        self.out_scale = float(self.output_stride/2)
        self.resnet_source = self.conf.get('mdn_resnet_source','slim')

        def train_pp(ims,locs,info):
            return preproc_func(ims,locs,info, conf,True, out_scale= self.out_scale)
        def val_pp(ims,locs,info):
            return preproc_func(ims,locs,info, conf, False, out_scale=self.out_scale)

        self.train_py_map = lambda ims, locs, info: tuple(tf.py_func( train_pp, [ims, locs, info], [tf.float32, tf.float32, tf.float32, tf.float32]))
        self.val_py_map = lambda ims, locs, info: tuple(tf.py_func( val_pp, [ims, locs, info], [tf.float32, tf.float32, tf.float32, tf.float32]))


    def create_network(self):
        import math

        im, locs, info, hmap = self.inputs
        conf = self.conf
        im.set_shape([conf.batch_size, conf.imsz[0]/conf.rescale,conf.imsz[1]/conf.rescale, conf.img_dim])
        osz0 = int(math.ceil(conf.imsz[0]/conf.rescale/(self.out_scale*2)))*2
        osz1 = int(math.ceil(conf.imsz[1]/conf.rescale/(self.out_scale*2)))*2
        hmap.set_shape([conf.batch_size, osz0,osz1,conf.n_classes])
        locs.set_shape([conf.batch_size, conf.n_classes,2])
        info.set_shape([conf.batch_size,3])
        if conf.img_dim == 1:
            im = tf.tile(im,[1,1,1,3])

        conv = lambda a, b: conv_relu3(
            a,b,self.ph['phase_train'], keep_prob=None,
            use_leaky=self.conf.unet_use_leaky)


        if self.resnet_source == 'slim':
            with slim.arg_scope(resnet_v1.resnet_arg_scope()):
                net, end_points = resnet_v1.resnet_v1_50(im,
                                          global_pool=False, is_training=self.ph[
                                          'phase_train'],output_stride=self.output_stride)
                l_names = ['conv1', 'block1/unit_2/bottleneck_v1', 'block2/unit_3/bottleneck_v1',
                           'block3/unit_5/bottleneck_v1', 'block4']
                down_layers = [end_points['resnet_v1_50/' + x] for x in l_names]

                ex_down_layers = conv(self.inputs[0], 64)
                down_layers.insert(0, ex_down_layers)
                n_filts = [32, 64, 64, 128, 256, 512]

        elif self.resnet_source == 'official_tf':
            mm = resnet_official.Model( resnet_size=50, bottleneck=True, num_classes=17, num_filters=32, kernel_size=7, conv_stride=2, first_pool_size=3, first_pool_stride=2, block_sizes=[3, 4, 6, 3], block_strides=[2, 2, 2, 2], final_size=2048, resnet_version=2, data_format='channels_last',dtype=tf.float32)
            im = tf.placeholder(tf.float32, [8, 512, 512, 3])
            resnet_out = mm(im, True)
            down_layers = mm.layers
            ex_down_layers = conv(self.inputs[0], 64)
            down_layers.insert(0, ex_down_layers)
            n_filts = [32, 64, 64, 128, 256, 512, 1024]


        with tf.variable_scope(self.net_name):

            num_outputs = self.conf.n_classes
            with slim.arg_scope([slim.conv2d, slim.conv2d_transpose], padding='SAME',
                                activation_fn=None, normalizer_fn=None):
                with tf.variable_scope('unet_out'):
                    pred = slim.conv2d_transpose(net, num_outputs,
                                                 kernel_size=[3, 3], stride=2,
                                                 scope='block4')
        return pred


    def get_var_list(self):
        var_list = tf.global_variables(self.net_name)
        for dep_net in self.dep_nets:
            var_list += dep_net.get_var_list()
        var_list += tf.global_variables('resnet_')
        return var_list
